#!/usr/bin/env bash

if ! sudo cat /etc/sysctl.conf | grep -q 'disable_ipv6' ; then 

cat << EOF | sudo tee -a /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1 
EOF

sudo sysctl -p

fi
