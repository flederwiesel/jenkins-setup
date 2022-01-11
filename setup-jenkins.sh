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

awk --version 2>&1 | grep -q '^GNU Awk' ||
{
	sed $'s/\\\\033/\033/g' <<-"EOF" >&2
		\033[1;37mThis script requires GNU awk.\033[m
		\033[1;37mPlease use `sudo apt install gawk` to install.\033[m

EOF

	exit 1
}

curl --version &>/dev/null ||
{
	sed $'s/\\\\033/\033/g' <<-"EOF" >&2
		\033[1;37mThis script requires curl.\033[m
		\033[1;37mPlease use `sudo apt install curl` to install.\033[m

EOF

	exit 1
}

apt update
apt upgrade --yes

# Install necessary binaries

# The docker.io install callback creates the docker group
apt install --yes default-jre docker.io

groupadd --system jenkins
useradd --system -g jenkins -s /sbin/nologin jenkins
usermod -aG docker jenkins
usermod -aG docker $SUDO_USER

useradd -g jenkins --no-create-home jenkins-setup
usermod -aG docker jenkins-setup

# exit/reconnect is required after usermod (self)...

mkdir -p /var/lib/jenkins

# The user in the docker image has uid 1000.
# We are going to mount this dir into the docker container, so it must be
# accessible to UID 1000...
chown 1000:jenkins /var/lib/jenkins

###

# Setup systemd

su jenkins-setup <<"EOF"
docker pull jenkins/jenkins:lts
#docker image ls
EOF

deluser jenkins-setup

cat <<"EOF" | tee /lib/systemd/system/jenkins.service
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

rm -f $HOME/jenkins-auth

while [[ ! -e $HOME/jenkins-auth ]]
do
	passwd=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword) &&
	{
		auth="admin:$passwd"
		echo "$auth" > $HOME/jenkins-auth
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
		@$HOME/jenkins-auth "$@"
}

# Initial Jenkins setup

mkdir -p "/home/$SUDO_USER/.jenkins-setup"

[[ -f "/home/$SUDO_USER/.jenkins-setup/jenkins.config" ]] ||
cp "${1:-default/jenkins.config}" "/home/$SUDO_USER/.jenkins-setup/jenkins.config"

[[ -f "/home/$SUDO_USER/.jenkins-setup/plugins" ]] ||
cp "default/plugins" "/home/$SUDO_USER/.jenkins-setup"

source "/home/$SUDO_USER/.jenkins-setup/jenkins.config"

#jenkins-cli help

#jenkins-cli list-plugins
jenkins-cli install-plugin $(awk '/^[^#]/ { print $1 }' "/home/$SUDO_USER/.jenkins-setup/plugins")

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

rm -rf "/home/$SUDO_USER/.jenkins-setup/credentials"
mkdir  "/home/$SUDO_USER/.jenkins-setup/credentials"

for cred in "${credentials[@]}"
do
	IFS=: read id username passphrase identity <<< "$cred"

	sed "s/<id>[^>]*</<id>$id</g
		s/<username>[^<]*</<username>$username</g
		s/<passphrase>[^<]*</<passphrase>$passphrase</g
		/<privateKey>/ a $(sed ":n N; s/\\n/\\\\n/g; tn" "$identity")" \
		"templates/credentials.xml" |
	tee "/home/$SUDO_USER/.jenkins-setup/credentials/$id.xml" |
	jenkins-cli import-credentials-as-xml system::system::jenkins
done

#jenkins-cli get-node

rm -rf "/home/$SUDO_USER/.jenkins-setup/nodes"
mkdir  "/home/$SUDO_USER/.jenkins-setup/nodes"

for node in "${nodes[@]}"
do
	IFS=: read hostname mac key cred <<< "$node"

	for credential in "${credentials[@]}"
	do
		IFS=: read id username unused identity <<< "$credential"

		if [[ $cred == $id ]]; then
			hostkey=$(ssh-keyscan "${hostname}" 2>/dev/null | awk "/$mac/"'{ print $3 }')

			if [[ $hostkey == $key ]]; then
				ssh_id+=("$username:$hostname:$identity")
			fi

			break;
		fi
	done

	jenkins-cli get-node "$hostname" &>/dev/null && op=update || op=create

	sed "s/<name>[^>]*</<name>$hostname</g
		s/<host>[^>]*</<host>$hostname</g
		s/<credentialsId>[^<]*</<credentialsId>$cred</g
		s/<passphrase>[^<]*</<passphrase>$passphrase</g
		s/<algorithm>[^<]*</<algorithm>$mac</g
		s,<key>[^<]*<,<key>$key<,g" \
		"templates/node.xml" |
	tee "/home/$SUDO_USER/.jenkins-setup/nodes/$hostname.xml" |

	jenkins-cli $op-node "$hostname"
done

#jenkins-cli list-jobs
#jenkins-cli get-job ''

rm -rf "/home/$SUDO_USER/.jenkins-setup/jobs"
mkdir  "/home/$SUDO_USER/.jenkins-setup/jobs"

for job in "${jobs[@]}"
do
	IFS=: read name url template script <<< "$job"

	jenkins-cli get-job "$name" &>/dev/null && op=update || op=create

	sed "s/<description>[^>]*</<description>$name</g
		s/<displayName>[^>]*</<displayName>$name</g
		s|<projectUrl>[^<]*<|<projectUrl>https://$url<|g
		/<script>$/ s/.*/<script>$(
			sed ':n N; s/\n/\\\\n/g; tn' "$script" |
			sed '
				s,\/,\\\/,g
				s/&/\\\&amp;/g;
				s/</\\\&lt;/g;
				s/>/\\\&gt;/g;
				s/\x22/\\\&quot;/g;
				s/\x27/\\\&apos;/g;
			'
			)/g " \
		"$template" |
	sed 's/\\n/\n/g' |
	tee "/home/$SUDO_USER/.jenkins-setup/jobs/$name.xml" |
	jenkins-cli $op-job "$name"
done

for copy in "${ssh_id[@]}"
do
	IFS=: read username hostname identity <<< "$copy"

	ssh-copy-id -o StrictHostKeyChecking=accept-new -i "$identity" "$username@$hostname"

	jenkins-cli connect-node     "$hostname"
	jenkins-cli wait-node-online "$hostname"
done
