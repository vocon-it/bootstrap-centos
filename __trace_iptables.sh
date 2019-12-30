#!/bin/bash
#
# Switches on/off tracing of traffic to/from a specific IP address
#

if [ $# -gt 1 ]; then
  echo "usage: $0 [<ip-address>|-d]"
  exit 1
fi

echo "BEFORE:"
iptables -t raw -L PREROUTING
iptables -t raw -L OUTPUT

IP=$1

if [ "$IP" == "-d" ]; then
  iptables -t raw -D OUTPUT 1
  iptables -t raw -D OUTPUT 1
  iptables -t raw -D PREROUTING 1
  iptables -t raw -D PREROUTING 1
else
  if [ "$IP" != "" ]; then
    modprobe ipt_LOG
    iptables -t raw -I OUTPUT 1 -s $IP/32 -j TRACE
    iptables -t raw -I OUTPUT 1 -d $IP/32 -j TRACE
    iptables -t raw -I PREROUTING 1 -s $IP/32 -j TRACE
    iptables -t raw -I PREROUTING 1 -d $IP/32 -j TRACE
  fi
fi

if [ "$IP" != "" ]; then
  echo "AFTER:"
  iptables -t raw -L PREROUTING
  iptables -t raw -L OUTPUT
fi
