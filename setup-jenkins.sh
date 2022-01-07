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

# Initial Jenkins setup

setupdir=$(realpath .jenkins-setup)

source "$setupdir/global.config"

cd /tmp

[ -e jenkins-cli.jar ] || wget http://localhost:8080/jnlpJars/jenkins-cli.jar

auth=admin:$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)

echo "$auth" > $HOME/jenkins-auth

jenkins-cli()
{
	java -jar jenkins-cli.jar -s http://localhost:8080/ -auth @$HOME/jenkins-auth "$@"
}

#jenkins-cli help

jenkins-cli list-plugins

jenkins-cli install-plugin $(awk '/^[^#]/ { print $1 }' "$setupdir/plugins")

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

# Set url

jenkins-cli groovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

jlc = JenkinsLocationConfiguration.get()
jlc.setUrl("$url")
jlc.save()
EOF

# Set admin address

jenkins-cli groovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

jlc = JenkinsLocationConfiguration.get()
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

for f in "$setupdir/credentials"/*.xml
do
	jenkins-cli import-credentials-as-xml system::system::jenkins < "$f"
done

#jenkins-cli get-node

for f in "$setupdir/nodes"/*.xml
do
	node=$(awk '/<name>/ { print gensub(/.*>([^<]+)<.*/, "\\1", "g") }' "$f")

	jenkins-cli create-node < "$f"
	jenkins-cli connect-node "$node"
	jenkins-cli wait-node-online "$node"
done

# Take built-in node offline
jenkins-cli offline-node ''

jenkins-cli restart
