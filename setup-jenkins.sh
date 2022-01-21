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

deps=(curl gawk default-jre docker.io jq xmlstarlet)

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

# Wait for Jenkins being up and running

while [[ -z "$auth" ]]
do
	passwd=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null) &&
	auth="admin:$passwd" ||
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

mkdir -p "$HOMEDIR/.jenkins-setup"
chgrp jenkins "$HOMEDIR/.jenkins-setup"
chmod og=rwx,g+s,o= "$HOMEDIR/.jenkins-setup"

# Get CLI

[ -e /usr/share/java/jenkins-cli.jar ] ||
wget -P /usr/share/java http://localhost:8080/jnlpJars/jenkins-cli.jar

jenkins-cli()
{
	java -jar /usr/share/java/jenkins-cli.jar \
		-s http://localhost:8080/ -auth \
		@$HOMEDIR/.jenkins-setup/auth "$@"
}

# Initial Jenkins setup

# Create files with rwx permissions for owner and group,
# so all users in the jenkins group have access

# BE CAREFUL NOT TO CREATE FILES OUTSIDE "$HOMEDIR/.jenkins-setup"
# as they all will have permissions we set here, which may not be
# what you want...

umask 007

echo "$auth" > "$HOMEDIR/.jenkins-setup/auth"

if [[ $1 ]]; then
	if [[ -f "$1" ]]; then
		cp "$1" "$HOMEDIR/.jenkins-setup/config.json"
	else
		echo "Could not find file $1." >&2
		exit 2
	fi
else
	[[ -f "$HOMEDIR/.jenkins-setup/config.json" ]] ||
	cp "$scriptdir/default/config.json" "$HOMEDIR/.jenkins-setup/config.json"
fi

[[ -f "$HOMEDIR/.jenkins-setup/plugins" ]] ||
cp "$scriptdir/default/plugins" "$HOMEDIR/.jenkins-setup"

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

global=$(jq -r 'to_entries[] |
	select(.key == "url" or .key == "admin") |
	"[" + .key + "]=" + (.value | @sh)' \
	"$HOMEDIR/.jenkins-setup/config.json"
)

declare -A "global=($global)"

jenkins-cli groovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

jlc = JenkinsLocationConfiguration.get()
jlc.setUrl('${global[url]}')
jlc.setAdminAddress('${global[admin]}')
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

credentials=$(
	jq -r '.credentials | to_entries |
		map({ "n": .key, "id": .value.id }) | .[] |
		"[" + .id + "]=" + (.n | tostring)' \
		"$HOMEDIR/.jenkins-setup/config.json"
)

declare -A "credentials=($credentials)"

for c in "${!credentials[@]}"
do
	xmldomain=com.cloudbees.plugins.credentials.domains.DomainCredentials
	xmlpkey=com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey

	cred=$(
		jq -r ".credentials[${credentials[$c]}]"' | to_entries |
			map("[\(.key)]=\("\"" + .value + "\"" // "")") | .[]' \
			"$HOMEDIR/.jenkins-setup/config.json"
	)

	declare -A "cred=($cred)"

	[[ -f "$HOMEDIR/.jenkins-setup/credentials/${cred[id]}.xml" ]] ||
	xmlstarlet ed \
		-u "/list/$xmldomain/credentials/$xmlpkey/id" -v "${cred[id]}" \
		-u "/list/$xmldomain/credentials/$xmlpkey/username" -v "${cred[username]}" \
		-u "/list/$xmldomain/credentials/$xmlpkey/passphrase" -v "${cred[keyfile-password]}" \
		-u "/list/$xmldomain/credentials/$xmlpkey/privateKeySource/privateKey" -v "$(cat ${cred[keyfile]})" \
		"$scriptdir/templates/credentials.xml" \
		> "$HOMEDIR/.jenkins-setup/credentials/${cred[id]}.xml"

	jenkins-cli import-credentials-as-xml system::system::jenkins \
		< "$HOMEDIR/.jenkins-setup/credentials/${cred[id]}.xml"
done

#jenkins-cli get-node

mkdir -p "$HOMEDIR/.jenkins-setup/nodes"

nodes=($(jq -r '.nodes[].hostname' "$HOMEDIR/.jenkins-setup/config.json"))

for n in "${nodes[@]}"
do
	node=$(
		jq -r '.nodes[] | select(.hostname == "'"$n"'") | to_entries |
			map("[\(.key)]=\("\"" + .value + "\"" // "")") | .[]' \
			"$HOMEDIR/.jenkins-setup/config.json"
	)

	declare -A "node=($node)"

	hostkey=$(ssh-keyscan "${node[hostname]}" 2>/dev/null | awk "/${node[host-mac]}/"'{ print $3 }')

	if [[ $hostkey == ${node[host-key]} ]]; then
		cred="${node[credentials]}"
		cred=$(jq -r ".credentials[${credentials[$cred]}]"' | to_entries |
				map("[\(.key)]=\("\"" + .value + "\"" // "")") | .[]' \
				"$HOMEDIR/.jenkins-setup/config.json"
		)

		declare -A "cred=($cred)"

		ssh_id+=("${cred[username]}:${node[hostname]}:${cred[keyfile]}")
	fi

	jenkins-cli get-node "${node[hostname]}" &>/dev/null && op=update || op=create

	[[ -f "$HOMEDIR/.jenkins-setup/nodes/${node[hostname]}.xml" ]] ||
	xmlstarlet ed \
		-u "/slave/name" -v "${node[hostname]}" \
		-u "/slave/remoteFS" -v "${node[root]}" \
		-u "/slave/launcher/host" -v "${node[hostname]}" \
		-u "/slave/launcher/credentialsId" -v "${node[credentials]}" \
		-u "/slave/launcher/sshHostKeyVerificationStrategy/key/algorithm" -v "${node[host-mac]}" \
		-u "/slave/launcher/sshHostKeyVerificationStrategy/key/key" -v "${node[host-key]}" \
		"$scriptdir/templates/node.xml" \
		> "$HOMEDIR/.jenkins-setup/nodes/${node[hostname]}.xml"

	jenkins-cli $op-node "${node[hostname]}" \
		< "$HOMEDIR/.jenkins-setup/nodes/${node[hostname]}.xml"
done

#jenkins-cli list-jobs
#jenkins-cli get-job ''

mkdir -p "$HOMEDIR/.jenkins-setup/jobs"

jobs=($(jq -r '.jobs[].name' "$HOMEDIR/.jenkins-setup/config.json"))

for j in "${jobs[@]}"
do
	job=$(
		jq -r '.jobs[] | select(.name == "'"$j"'") | to_entries |
			map("[\(.key)]=\("\"" + .value + "\"" // "")") | .[]' \
			"$HOMEDIR/.jenkins-setup/config.json"
	)

	declare -A "job=($job)"

	jenkins-cli get-job "${job[name]}" &>/dev/null && op=update || op=create

	[[ -f "$HOMEDIR/.jenkins-setup/jobs/${job[name]}.xml" ]] ||
	xmlstarlet ed \
		-u "/flow-definition/definition/script" -v "$(sed "s/%{node}/${job[node]}/g" "${job[pipeline-script]}")" \
		-u "/flow-definition/displayName" -v "${job[name]}" \
		-u "/flow-definition/description" -v "${job[name]}" \
		-u "/flow-definition/projectUrl" -v "${job[project-url]}" \
		"${job[xml-template]}" \
		> "$HOMEDIR/.jenkins-setup/jobs/${job[name]}.xml"

	jenkins-cli $op-job "${job[name]}" \
		< "$HOMEDIR/.jenkins-setup/jobs/${job[name]}.xml"
done

for copy in "${ssh_id[@]}"
do
	IFS=: read username hostname identity <<< "$copy"

	ssh-copy-id -o StrictHostKeyChecking=accept-new -i "$identity" "$username@$hostname"

	jenkins-cli connect-node     "$hostname"
	jenkins-cli wait-node-online "$hostname"
done
