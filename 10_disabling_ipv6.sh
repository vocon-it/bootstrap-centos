#!/usr/bin/env bash

# Exit on error:
set -e

sudo cat /etc/sysctl.conf | grep -q 'disable_ipv6' && echo "ipv6 already disabled. Nothing to do" && exit 0

cat << EOF | sudo tee -a /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1 
EOF

sudo sysctl -p
