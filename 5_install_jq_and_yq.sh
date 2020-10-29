#!/bin/sh

# Exit on error:
set -e

jq --version && echo "jq is already installed. nothing to do." && exit 0

# repo
yum install -y epel-release

# install jq:
yum install -y jq
jq --version

# install yq, i.e. the yaml pendant of jq:
sudo yum install -y python2-pip-8.1.2-8.el7.noarch || sudo yum -install -y python2-pip
sudo pip install yq

