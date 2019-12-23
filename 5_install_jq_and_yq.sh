#!/bin/sh

# repo
yum install epel-release -y

# install jq:
yum install jq -y
jq --version

# install yq, i.e. the yaml pendant of jq:
sudo yum -y install python2-pip-8.1.2-8.el7.noarch || sudo yum -y install python2-pip
sudo pip install yq

