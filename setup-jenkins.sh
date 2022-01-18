#!/bin/bash

# To update jenkins docker image, run:
# ```
# systemctl stop jenkins
# docker pull jenkins/jenkins:lts
# systemctl start jenkins
# ```

if [ "$EUID" != "0" ]; then
	echo "Script must be run as root." >&2
	exit 1
fi

readonly HOMEDIR=$(eval echo ~$(printf %q "$SUDO_USER"))
readonly scriptdir=$(dirname "$(realpath "$0")")

deps=(curl gawk default-jre docker.io xmlstarlet)

for d in "${deps[@]}"
do
	dpkg --list "$d" | grep -q '^ii' || install+=("$d")
done

if [[ ${install[@]} ]]; then
	# Install necessary binaries
	# The docker.io install callback creates the docker group

	apt update
	apt upgrade --yes
	apt install --yes "${install[@]}"
fi

getent group jenkins &>/dev/null ||
groupadd --system jenkins

getent passwd jenkins &>/dev/null ||
useradd --system -g jenkins -s /sbin/nologin jenkins

gid=$(getent group jenkins)

id $SUDO_USER | grep -q "groups=.*\<$gid\>" ||
usermod -aG jenkins $SUDO_USER

gid=$(getent group docker)

id jenkins | grep -q "groups=.*\<$gid\>" ||
usermod -aG docker jenkins

id $SUDO_USER | grep -q "groups=.*\<$gid\>" ||
usermod -aG docker $SUDO_USER

# exit/reconnect is required after usermod (self)...

mkdir -p /var/lib/jenkins

# The user in the docker image has uid 1000.
# We are going to mount this dir into the docker container, so it must be
# accessible to UID 1000...
chown 1000:jenkins /var/lib/jenkins

###

docker pull jenkins/jenkins:lts
#docker image ls

# Setup systemd
cat <<"EOF" > /lib/systemd/system/jenkins.service
[Unit]
Description=Jenkins Server
Documentation=https://jenkins.io/doc/
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=jenkins
Group=jenkins
SyslogIdentifier=jenkins
TimeoutStartSec=0
Restart=on-failure
RestartSec=30s
#ExecStartPre=-/usr/bin/docker pull jenkins/jenkins:lts
ExecStart=/usr/bin/docker run \
	--rm \
	--name jenkins \
	--publish 8080:8080 \
	--volume /var/lib/jenkins:/var/jenkins_home \
	jenkins/jenkins:lts
ExecStop=/usr/bin/docker stop jenkins

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable jenkins
systemctl start  jenkins
systemctl status jenkins --no-pager

state=undefined

# Initial Jenkins setup

mkdir -p "$HOMEDIR/.jenkins-setup"
chgrp jenkins "$HOMEDIR/.jenkins-setup"
chmod og=rwx,g+s,o= "$HOMEDIR/.jenkins-setup"

# Create files with rwx permissions for owner and group,
# so all users in the jenkins group have access

# BE CAREFUL NOT TO CREATE FILES OUTSIDE "$HOMEDIR/.jenkins-setup"
# as they all will have permissions we set here, which may not be
# what you want...

umask 007

rm -f "$HOMEDIR/jenkins-auth"

while [[ ! -e "$HOMEDIR/jenkins-auth" ]]
do
	passwd=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null) &&
	{
		auth="admin:$passwd"
		echo "$auth" > "$HOMEDIR/jenkins-auth"
		chgrp jenkins "$HOMEDIR/jenkins-auth"
	} ||
	sleep 1
done

# After startup, Jenkis will issue the following error / status code / HTML:
# 56
# 0: 503: Please wait while Jenkins is getting ready to work
# 0: 403: Authentication required
until [ "${result:0:1}" = "2" ]
do
	result=$(curl -sS -w '%{stderr}%{http_code}' --user "$auth" http://localhost:8080/ 2>/dev/null 3>&1 1>&2 2>&3)
	echo $?:$result

	[ "${result:0:1}" = "2" ] || sleep 1
done

[ -e /usr/share/java/jenkins-cli.jar ] ||
wget -P /usr/share/java http://localhost:8080/jnlpJars/jenkins-cli.jar

jenkins-cli()
{
	java -jar /usr/share/java/jenkins-cli.jar \
		-s http://localhost:8080/ -auth \
		@$HOMEDIR/jenkins-auth "$@"
}

if [[ $1 ]]; then
	if [[ -f "$1" ]]; then
		cp "$1" "$HOMEDIR/.jenkins-setup/jenkins.config"
	else
		echo "Could not find file $1." >&2
		exit 2
	fi
else
	[[ -f "$HOMEDIR/.jenkins-setup/jenkins.config" ]] ||
	cp "$scriptdir/default/jenkins.config" "$HOMEDIR/.jenkins-setup/jenkins.config"
fi

[[ -f "$HOMEDIR/.jenkins-setup/plugins" ]] ||
cp "$scriptdir/default/plugins" "$HOMEDIR/.jenkins-setup"

source "$HOMEDIR/.jenkins-setup/jenkins.config"

#jenkins-cli help

#jenkins-cli list-plugins
jenkins-cli install-plugin $(awk '/^[^#]/ { print $1 }' "$HOMEDIR/.jenkins-setup/plugins")

jenkins-cli restart

# Shortly before restart, Jenkis will issue the following error / status code / HTML:
# 0: 503: Please wait while Jenkins is restarting

until [ "${result:0:1}" = "5" ]
do
	result=$(curl -sS -w '%{stderr}%{http_code}' --user "$auth" http://localhost:8080/ 2>/dev/null 3>&1 1>&2 2>&3)
	echo $?:$result

	[ "${result:0:1}" = "5" ] || sleep 1
done

# After restart, Jenkis will issue the following error / status code / HTML:
# 56
# 0: 503: Please wait while Jenkins is getting ready to work
# 0: 403: Authentication required
until [ "${result:0:1}" = "2" ]
do
	result=$(curl -sS -w '%{stderr}%{http_code}' --user "$auth" http://localhost:8080/ 2>/dev/null 3>&1 1>&2 2>&3)
	echo $?:$result

	[ "${result:0:1}" = "2" ] || sleep 1
done

# Set url / admin address

jenkins-cli groovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

jlc = JenkinsLocationConfiguration.get()
jlc.setUrl('$url')
jlc.setAdminAddress('$admin')
jlc.save()
EOF

# Complete setup

jenkins-cli groovy = <<"EOF"
#!groovy

import jenkins.model.*
import jenkins.install.*;

def instance = Jenkins.getInstance()
// Disable Setup Wizard
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
EOF

#jenkins-cli list-credentials-as-xml system::system::jenkins
#jenkins-cli get-credentials-as-xml system::system::jenkins '(global)' ssh-flederwiesel-ubuntu-devel

mkdir -p "$HOMEDIR/.jenkins-setup/credentials"

for cred in "${credentials[@]}"
do
	IFS=: read id username passphrase identity <<< "$cred"

	xmldomain=com.cloudbees.plugins.credentials.domains.DomainCredentials
	xmlpkey=com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey

	[[ -f "$HOMEDIR/.jenkins-setup/credentials/$id.xml" ]] ||
	xmlstarlet ed \
		-u "/list/$xmldomain/credentials/$xmlpkey/id" -v "$id" \
		-u "/list/$xmldomain/credentials/$xmlpkey/username" -v "$username" \
		-u "/list/$xmldomain/credentials/$xmlpkey/passphrase" -v "$passphrase" \
		-u "/list/$xmldomain/credentials/$xmlpkey/privateKeySource/privateKey" -v "$(cat $identity)" \
		"$scriptdir/templates/credentials.xml" \
		> "$HOMEDIR/.jenkins-setup/credentials/$id.xml"

	jenkins-cli import-credentials-as-xml system::system::jenkins \
		< "$HOMEDIR/.jenkins-setup/credentials/$id.xml"
done

#jenkins-cli get-node

mkdir -p "$HOMEDIR/.jenkins-setup/nodes"

for node in "${nodes[@]}"
do
	IFS=: read hostname mac key cred rootdir <<< "$node"

	for credential in "${credentials[@]}"
	do
		IFS=: read id username passphrase keyfile <<< "$credential"

		if [[ $cred == $id ]]; then
			hostkey=$(ssh-keyscan "${hostname}" 2>/dev/null | awk "/$mac/"'{ print $3 }')

			if [[ $hostkey == $key ]]; then
				ssh_id+=("$username:$hostname:$identity")
			fi

			break;
		fi
	done

	jenkins-cli get-node "$hostname" &>/dev/null && op=update || op=create

	[[ -f "$HOMEDIR/.jenkins-setup/nodes/$hostname.xml" ]] ||
	xmlstarlet ed \
		-u "/slave/name" -v "$hostname" \
		-u "/slave/remoteFS" -v "$rootdir" \
		-u "/slave/launcher/host" -v "$hostname" \
		-u "/slave/launcher/credentialsId" -v "$cred" \
		-u "/slave/launcher/sshHostKeyVerificationStrategy/key/algorithm" -v "$mac" \
		-u "/slave/launcher/sshHostKeyVerificationStrategy/key/key" -v "$key" \
		"$scriptdir/templates/node.xml" \
		> "$HOMEDIR/.jenkins-setup/nodes/$hostname.xml"

	jenkins-cli $op-node "$hostname" \
		< "$HOMEDIR/.jenkins-setup/nodes/$hostname.xml"
done

#jenkins-cli list-jobs
#jenkins-cli get-job ''

mkdir -p "$HOMEDIR/.jenkins-setup/jobs"

for job in "${jobs[@]}"
do
	IFS=: read name url template script node <<< "$job"

	jenkins-cli get-job "$name" &>/dev/null && op=update || op=create

	[[ -f "$HOMEDIR/.jenkins-setup/jobs/$name.xml" ]] ||
	xmlstarlet ed \
		-u "/flow-definition/definition/script" -v "$(sed "s/%{node}/$node/g" "$script")" \
		-u "/flow-definition/displayName" -v "$name" \
		-u "/flow-definition/description" -v "$name" \
		-u "/flow-definition/projectUrl" -v "https://$url" \
		"$template" \
		> "$HOMEDIR/.jenkins-setup/jobs/$name.xml"

	jenkins-cli $op-job "$name" \
		< "$HOMEDIR/.jenkins-setup/jobs/$name.xml"
done

for copy in "${ssh_id[@]}"
do
	IFS=: read username hostname identity <<< "$copy"

	ssh-copy-id -o StrictHostKeyChecking=accept-new -i "$identity" "$username@$hostname"

	jenkins-cli connect-node     "$hostname"
	jenkins-cli wait-node-online "$hostname"
done
