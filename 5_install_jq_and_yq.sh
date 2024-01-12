#!/bin/sh

# Exit on error:
set -e

# repo for Centos 7
sudo yum install -y epel-release || true

if jq --version >/dev/null; then
  echo "jq is already installed. nothing to do."
else
  sudo yum install -y jq
fi
jq --version

if yq --version >/dev/null 2>/dev/null; then
  echo "yq is already installed. nothing to do."
else
  sudo yum install -y pip || true
  sudo pip install yq
fi
yq --version

