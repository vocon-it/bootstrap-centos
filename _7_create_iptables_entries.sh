#!/bin/bash

USAGE="Usage: $0 dyndns-name1 dyndns-name2 ... dyndns-nameN"

[ "$DYNDNSNAME" == "" ] && DYNDNSNAME=vocon-home.mooo.com

if [ "$#" == "0" ]; then
	echo "$USAGE"
	exit 1
fi

yum list installed | grep bind-utils || yum install -y bind-utils

while (( "$#" )); do

  DYNDNSNAME=$1
  LAST_IP_FILE=~/${DYNDNSNAME}_IP

  # check, whether DYNDNSNAME is a plain IP address:
  re='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'
    re+='0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))$'
  [[ $DYNDNSNAME =~ $re ]] && ISIP=true || ISIP=false
  echo DYNDNSNAME=$DYNDNSNAME
  echo ISIP=$ISIP

  if [ "$ISIP" == "true" ]; then
    Current_IP=$DYNDNSNAME
  else
    Current_IP=$(host $DYNDNSNAME | cut -f4 -d' ')
  fi

  Current_IP=$Current_IP

  if [ ! -e $LAST_IP_FILE ] ; then
    iptables -I INPUT -i eth0 -s $Current_IP -j ACCEPT
    echo $Current_IP > $LAST_IP_FILE
  else 
    Old_IP=$(cat $LAST_IP_FILE)

    if [ "$Current_IP" == "$Old_IP" ] ; then
      echo IP address has not changed
    else
      LINE_NUMBER=$(iptables -L INPUT --line-numbers -n | grep $Old_IP | awk '{print $1}')
      iptables -D INPUT -i eth0 -s $Old_IP -j ACCEPT
      iptables -I INPUT $LINE_NUMBER -i eth0 -s $Current_IP -j ACCEPT
      /etc/init.d/iptables save
      echo $Current_IP > $LAST_IP_FILE
      echo iptables have been updated
    fi
  fi

shift

done

# prepend a rule that accepts all outgoing traffic, if not already present:
iptables -L INPUT --line-numbers -n | grep "ACCEPT" | grep "state RELATED,ESTABLISHED" || iptables -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# append a reject any, if not already present:
iptables -L INPUT --line-numbers -n | grep "REJECT" | grep "0\.0\.0\.0\/0[ \t]*0\.0\.0\.0\/0" || iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
