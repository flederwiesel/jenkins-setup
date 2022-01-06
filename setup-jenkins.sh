#!/bin/bash

jenkins=http://ubuntu-devel:8080/

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
systemctl start jenkins
systemctl status jenkins

# Initial Jenkins setup

cd /tmp

[ -e jenkins-cli.jar ] || wget http://localhost:8080/jnlpJars/jenkins-cli.jar

passwd=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)

echo "admin:$passwd" > $HOME/passwd

jenkins-cli()
{
	java -jar jenkins-cli.jar -s http://localhost:8080/ -auth @$HOME/passwd "$@"
}

#jenkins-cli help

jenkins-cli list-plugins

jenkins-cli install-plugin \
$(awk '/^[^#]/ { print $1 }' <<"EOF"
### Organization and Administration

# Dashboard View
# Customizable dashboard that can present various views of job information.
# https://plugins.jenkins.io/dashboard-view
dashboard-view                     Dashboard View                                  2.18

# Folders
# This plugin allows users to create "folders" to organize jobs. Users can
# define custom taxonomies (like by project type, organization type etc).
# Folders are nestable and you can define views within folders.
# Maintained by CloudBees, Inc.
# https://plugins.jenkins.io/cloudbees-folder
cloudbees-folder                   Folders Plugin                                  6.17

# Configuration as Code
# This plugin allows configuration of Jenkins based on human-readable
# declarative configuration files.
# https://plugins.jenkins.io/configuration-as-code
configuration-as-code              Configuration as Code Plugin                    1.55

# OWASP Markup Formatter
# Uses the OWASP Java HTML Sanitizer to allow safe-seeming HTML markup to be
# entered in project descriptions and the like.
# https://plugins.jenkins.io/antisamy-markup-formatter
antisamy-markup-formatter          OWASP Markup Formatter Plugin                   2.5

### Build Features

# Build Name and Description Setter
# This plug-in sets the display name and description of a build to something
# other than #1, #2, #3, ... Now also with support for build description and
# pipeline approach.
# https://plugins.jenkins.io/build-name-setter
build-name-setter                  Build Name and Description Setter               2.2.0

# Build Timeout
# This plugin allows builds to be automatically terminated after the specified
# amount of time has elapsed.
# https://plugins.jenkins.io/build-timeout
build-timeout                      Build Timeout                                   1.20

# Config File Provider
# Ability to provide configuration files (e.g. settings.xml for maven, XML,
# groovy, custom files,...) loaded through the UI which will be copied to the
# job workspace.
# https://plugins.jenkins.io/config-file-provider
config-file-provider               Config File Provider Plugin                     3.8.2

# Credentials Binding
# Allows credentials to be bound to environment variables for use from
# miscellaneous build steps.
# https://plugins.jenkins.io/credentials-binding
credentials-binding                Credentials Binding Plugin                      1.27

# Embeddable Build Status
# This plugin adds the embeddable build status badge to Jenkins so that you can
# easily hyperlink/show your build status from elsewhere.
# https://plugins.jenkins.io/embeddable-build-status
embeddable-build-status            Embeddable Build Status Plugin                  2.0.3

# Rebuilder
# This plugin is for rebuilding a job using the same parameters.
# https://plugins.jenkins.io/rebuild
rebuild                            Rebuilder                                       1.32

# SSH Agent
# This plugin allows you to provide SSH credentials to builds via a ssh-agent in
# Jenkins.
# https://plugins.jenkins.io/ssh-agent
ssh-agent                          SSH Agent Plugin                                1.23

# Throttle Concurrent Builds
# This plugin allows for throttling the number of concurrent builds of a project
# running per node or globally.
# https://plugins.jenkins.io/throttle-concurrents
throttle-concurrents               Throttle Concurrent Builds Plug-in              2.5

# Timestamper
# Adds timestamps to the Console Output
# https://plugins.jenkins.io/timestamper
timestamper                        Timestamper                                     1.15

# Workspace Cleanup
# This plugin deletes the project workspace when invoked.
# https://plugins.jenkins.io/ws-cleanup
ws-cleanup                         Workspace Cleanup Plugin                        0.39

### Build Tools

# Ant Adds Apache Ant support to Jenkins
# https://plugins.jenkins.io/ant
ant                                Ant Plugin                                      1.13

# Gradle
# This plugin allows Jenkins to invoke Gradle build scripts directly.
# https://plugins.jenkins.io/gradle
gradle                             Gradle Plugin                                   1.37.1

# MSBuild
# This plugin makes it possible to build a Visual Studio project (.proj) and
# solution files (.sln).
# https://plugins.jenkins.io/msbuild
msbuild                            MSBuild Plugin                                  1.30

# NodeJS
# NodeJS Plugin executes NodeJS script as a build step.
# https://plugins.jenkins.io/nodejs
nodejs                             NodeJS Plugin                                   1.4.3

### Build Analysis and Reporting

# Cobertura
# This plugin integrates Cobertura coverage reports to Jenkins.
# https://plugins.jenkins.io/cobertura
cobertura                          Cobertura Plugin                                1.17

# HTML Publisher
# This plugin publishes HTML reports.
# https://plugins.jenkins.io/htmlpublisher
htmlpublisher                      HTML Publisher plugin                           1.28

# JUnit
# Allows JUnit-format test results to be published.
# https://plugins.jenkins.io/junit
junit                              JUnit Plugin                                    1.53

# Warnings Next Generation
# This plugin collects compiler warnings or issues reported by static analysis
# tools and visualizes the results. It has built-in support for many
# compilers (cpp, clang, java, ...) and
# tools (spotbugs, pmd, checkstyle, eslint, phpstan, ...), see the list of
# supported report formats.
# https://plugins.jenkins.io/warnings-ng
warnings-ng                        Warnings Next Generation Plugin                 9.10.2

# xUnit
# This plugin makes it possible to record xUnit test reports.
# https://plugins.jenkins.io/xunit
xunit                              xUnit plugin                                    3.0.5

### Pipelines and Continuous Delivery

# Pipeline
# A suite of plugins that lets you orchestrate automation, simple or complex.
# See Pipeline as Code with Jenkins for more details.
# https://plugins.jenkins.io/workflow-aggregator
workflow-aggregator                Pipeline                                        2.6

# GitHub
# Branch Source Multibranch projects and organization folders from GitHub.
# Maintained by CloudBees, Inc.
# https://plugins.jenkins.io/github-branch-source
github-branch-source               GitHub Branch Source Plugin                     2.11.3

# Pipeline: GitHub Groovy Libraries
# Allows Pipeline Grrovy libraries to be loaded on the fly from GitHub.
# https://plugins.jenkins.io/pipeline-github-lib
pipeline-github-lib                Pipeline: GitHub Groovy Libraries               1.0

# Pipeline: Stage View
# Pipeline Stage View Plugin.
# https://plugins.jenkins.io/pipeline-stage-view
pipeline-stage-view                Pipeline: Stage View Plugin                     2.20

# Conditional BuildStep
# A buildstep wrapping any number of other buildsteps, controlling their
# execution based on a defined condition (e.g. BuildParameter).
# https://plugins.jenkins.io/conditional-buildstep
conditional-buildstep              Conditional BuildStep                           1.4.1

# Multijob
# This plugin is a MultiJob plugin.
# https://plugins.jenkins.io/jenkins-multijob-plugin
jenkins-multijob-plugin            Multijob plugin                                 1.36

# Parameterized Trigger
# The Jenkins Plugins Parent POM Project
# https://plugins.jenkins.io/parameterized-trigger
parameterized-trigger              Parameterized Trigger plugin                    2.43

# Copy Artifact
# Adds a build step to copy artifacts from another project.
# https://plugins.jenkins.io/copyartifact
copyartifact                       Copy Artifact Plugin                            1.46.2

# Bitbucket
# Integrates with BitBucket
# https://plugins.jenkins.io/bitbucket
bitbucket                          Bitbucket Plugin                                214.v2fd4234d0554

# ClearCase This plugin makes it possible to retrieve files from a ClearCase SCM
# using a configspec.
# https://plugins.jenkins.io/clearcase
clearcase                          ClearCase Plug-in                               1.6.8

# CVS
# Integrates Jenkins with CVS version control system using a modified version of
# the Netbeans cvsclient.
# https://plugins.jenkins.io/cvs
cvs                                CVS Plug-in                                     2.19

# Git
# This plugin integrates Git with Jenkins.
# https://plugins.jenkins.io/git
git                                Git plugin                                      4.10.1

# Git Parameter
# Adds ability to choose branches, tags or revisions from git repositories
# configured in project.
# https://plugins.jenkins.io/git-parameter
git-parameter                      Git Parameter Plug-In                           0.9.14

# GitHub
# This plugin integrates GitHub to Jenkins.
# https://plugins.jenkins.io/github
github                             GitHub plugin                                   1.34.1

# GitLab
# This plugin allows GitLab to trigger Jenkins builds and display their results
# in the GitLab UI.
# https://plugins.jenkins.io/gitlab-plugin
gitlab-plugin                      GitLab Plugin                                   1.5.25

# P4
# Perforce Client plugin for the Jenkins SCM provider. The plugin includes
# extension points for: Perforce Password and Ticket Credentials storeWorkspace
# management for static, manual, template and streamAction point for Review Builds
# https://plugins.jenkins.io/p4
p4                                 P4 Plugin                                       1.11.6

# REPO
# This plugin allows use of repo as an SCM tool. A repo binary is required.
# https://plugins.jenkins.io/repo
repo                               REPO plugin                                     1.14.0

# Subversion
# The Jenkins Plugins Parent POM Project
# https://plugins.jenkins.io/subversion
subversion                         Subversion Plug-in                              2.15.1

### Distributed Builds

# Matrix Project
# Multi-configuration (matrix) project type.
# https://plugins.jenkins.io/matrix-project
matrix-project                     Matrix Project Plugin                           1.19

# SSH Build Agents
# Allows to launch agents over SSH, using a Java implementation of the SSH protocol.
# https://plugins.jenkins.io/ssh-slaves
ssh-slaves                         SSH Build Agents plugin                         1.33.0

# WMI Windows Agents
# Allows you to setup agents on Windows machines over
# Windows Management Instrumentation (WMI)
# https://plugins.jenkins.io/windows-slaves
windows-slaves                     WMI Windows Agents Plugin                       1.8

### User Management and Security

# Matrix Authorization Strategy
# Offers matrix-based security authorization strategies (global and per-project).
# https://plugins.jenkins.io/matrix-auth
matrix-auth                        Matrix Authorization Strategy Plugin            3.0

# PAM Authentication
# Adds Unix Pluggable Authentication Module (PAM) support to Jenkins
# https://plugins.jenkins.io/pam-auth
pam-auth                           PAM Authentication plugin                       1.6.1

# LDAP
# Adds LDAP authentication to Jenkins
# https://plugins.jenkins.io/ldap
ldap                               LDAP Plugin                                     2.7

# Role-based Authorization Strategy
# Enables user authorization using a Role-Based strategy. Roles can be defined
# globally or for particular jobs or nodes selected by regular expressions.
# https://plugins.jenkins.io/role-strategy
role-strategy                      Role-based Authorization Strategy               3.2.0

# Active Directory
# This plugin enables authentication through Active Directory.
# https://plugins.jenkins.io/active-directory
active-directory                   Active Directory plugin                         2.25

# Authorize Project
# Configure projects to run with specified authorization.
# https://plugins.jenkins.io/authorize-project
authorize-project                  Authorize Project                               1.4.0

### Notifications and Publishing

# Email Extension
# This plugin is a replacement for Jenkins's email publisher. It allows to
# configure every aspect of email notifications: when an email is sent, who
# should receive it and what the email says
# https://plugins.jenkins.io/email-ext
email-ext                          Email Extension Plugin                          2.86

# Email Extension Template
# This plugin allows administrators to create global templates for the Extended
# Email Publisher.
# https://plugins.jenkins.io/emailext-template
emailext-template                  Email Extension Template Plugin                 1.2

# Mailer
# This plugin allows you to configure email notifications for build results
# https://plugins.jenkins.io/mailer
mailer                             Mailer Plugin                                   1.34

# Publish Over SSH
# Send build artifacts over SSH
# https://plugins.jenkins.io/publish-over-ssh
publish-over-ssh                   Publish Over SSH                                1.22

# SSH
# This plugin executes shell commands remotely using SSH protocol.
# https://plugins.jenkins.io/ssh
ssh                                SSH plugin                                      2.6.1

### Languages

# Locale
# This plugin lets you control the language of Jenkins.
# https://plugins.jenkins.io/locale
locale                             Locale plugin                                   1.4
)

jenkins-cli restart

# After restart, Jenkis will issue the following error / status code / HTML:
# 0: 503: Please wait while Jenkins is restarting
# 56
# 0: 503: Please wait while Jenkins is getting ready to work
# 0: 403: Authentication required
until [ "${result:0:1}" = "4" ]
do
	result=$(curl -s -w '%{stderr}%{http_code}' http://localhost:8080/ 2>/dev/null 3>&1 1>&2 2>&3)
	echo $?:$result

	[ "${result:0:1}" = "4" ] || sleep 1
done

exit

#jenkins-cli list-credentials-as-xml system::system::jenkins
#jenkins-cli get-credentials-as-xml system::system::jenkins '(global)' ssh-flederwiesel-ubuntu-devel
jenkins-cli import-credentials-as-xml system::system::jenkins <<"EOF"
<list>
  <com.cloudbees.plugins.credentials.domains.DomainCredentials plugin="credentials@1055.v1346ba467ba1">
    <domain>
      <specifications/>
    </domain>
    <credentials>
      <com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@1.19">
        <scope>GLOBAL</scope>
        <id>ssh-flederwiesel-ubuntu-devel</id>
        <description></description>
        <username>flederwiesel</username>
        <usernameSecret>true</usernameSecret>
        <passphrase></passphrase>
        <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey$DirectEntryPrivateKeySource">
          <privateKey>
-----BEGIN OPENSSH PRIVATE KEY-----
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
-----END OPENSSH PRIVATE KEY-----
          </privateKey>
        </privateKeySource>
      </com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
    </credentials>
  </com.cloudbees.plugins.credentials.domains.DomainCredentials>
</list>
EOF

#jenkins-cli get-node
jenkins-cli create-node <<"EOF"
<slave>
  <name>ubuntu-devel</name>
  <description></description>
  <remoteFS>/tmp</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy$Demand">
    <inDemandDelay>0</inDemandDelay>
    <idleDelay>59</idleDelay>
  </retentionStrategy>
  <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.33.0">
    <host>ubuntu-devel</host>
    <port>22</port>
    <credentialsId>ssh-flederwiesel-ubuntu-devel</credentialsId>
    <launchTimeoutSeconds>60</launchTimeoutSeconds>
    <maxNumRetries>10</maxNumRetries>
    <retryWaitTime>15</retryWaitTime>
    <sshHostKeyVerificationStrategy class="hudson.plugins.sshslaves.verifiers.ManuallyProvidedKeyVerificationStrategy">
      <key>
        <algorithm>ssh-rsa</algorithm>
        <key>AAAAB3NzaC1yc2EAAAADAQABAAABgQDK4N854H17BrJGE+xJzjwxoLZZ92arM8SKCYySeeuqL9gwdaz9Dm1kUkKq+biJemL8L/vXgvO3OdBS4isK66N0czwGM2eb8w5aALHJV+Y52Z0nul8eIdwskNzWAz1a0ioxm8geYBDl8/5V+BbwW8Ivuz5XzIEzmGScNPIzFDZnJPPgVdkviOojhxHNy2td9akQxzBOO0wfjyIoY5CX+Ao/fHb+FL39UNu5vaA+jYdDTRVI+Rmvt2kOVkinF8AGce/dMTHUGSySVxPhFrEAwOLILZnXDVM3S/zyzOgZpYmHxL6qRyygKOJ1tOu3YSazCJszufYBx9gHxGtNvJNagfERMaKZbf7qTDbEQ2XCnJ72G/E6W8edevZ0uUcTNFtbIsIPqjS6p1vKXKr1NRLp7m3RvjArDbv/q3eaQl6arpzWLgoeG+hTN25PSrgzIeqLTwM5JkAF/Dp5an441mEi4lzkhJkbG8zGqjEqeDZx87q2a/fQjbnA0IQx0Voa6X9VY+8=</key>
      </key>
    </sshHostKeyVerificationStrategy>
    <tcpNoDelay>true</tcpNoDelay>
  </launcher>
  <label></label>
  <nodeProperties/>
</slave>
EOF

jenkins-cli online-node ubuntu-devel
jenkins-cli wait-node-online ubuntu-devel
# Take built-in node offline
jenkins-cli offline-node ''

# Set url

jenkins-cli groovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

jlc = JenkinsLocationConfiguration.get()
jlc.setUrl("$jenkins")
jlc.save()
EOF

# Set admin address

jenkins-cli groovy = <<"EOF"
import jenkins.model.JenkinsLocationConfiguration

jlc = JenkinsLocationConfiguration.get()
jlc.setAdminAddress("\"Jenkins Admin\" <admin@ubuntu-devel>")
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

jenkins-cli restart
