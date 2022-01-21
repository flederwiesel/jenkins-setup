# Jenkins setup

This project provides a scripted setup a very basic Jenkins instance on a
debian-like system (Debian, Ubuntu, Mint, ...).

## Requirements

As the Jenkins server is run as docker container, `docker` is required.
Further, `default-jre` is required by Jenkins and `curl`, `gawk` are needed
during the setup. Missing requirements will be installed automatically
during the setup process.

## Setup

`setup-jenkins.sh` must be run as root, optionally specifying a
config file -- see `default/jenkins.config` for an example.
