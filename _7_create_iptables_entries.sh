#!/bin/bash

USAGE="Usage: $0 dyndns-name1 dyndns-name2 ... dyndns-nameN"

#[ "$DYNDNSNAME" == "" ] && DYNDNSNAME=vocon-home.mooo.com
DEBUG=

if [ "$#" == "0" ]; then
	echo "$USAGE"
	exit 1
fi

IPTABLES=/usr/sbin/iptables
yum list installed | grep bind-utils 1>/dev/null || yum install -y bind-utils

date
while (( "$#" )); do

  DYNDNSNAME=$1
  LAST_IP_FILE=~/${DYNDNSNAME}_IP

  # check, whether DYNDNSNAME is a plain IP address:
  re='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'
    re+='0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))$'
  [[ $DYNDNSNAME =~ $re ]] && ISIP=true || ISIP=false
  [ "$DEBUG" == "true" ] && echo DYNDNSNAME=$DYNDNSNAME

  if [ "$ISIP" == "true" ]; then
    Current_IP=$DYNDNSNAME
  else
    Current_IP=$(host $DYNDNSNAME | cut -f4 -d' ')
  fi

  # Current_IP
  Current_IP=$Current_IP
  [ "$DEBUG" == "true" ] && echo Current_IP=$Current_IP

  # Old_IP
  [ -e $LAST_IP_FILE ] && Old_IP=$(cat $LAST_IP_FILE) || unset Old_IP
  [ "$DEBUG" == "true" ] && echo Old_IP=$Old_IP

  # FOUND_IPTABLES_ENTRY
  [ "$Old_IP" != "" ] && FOUND_IPTABLES_ENTRY="$($IPTABLES -L INPUT -n | grep $Old_IP)" || unset FOUND_IPTABLES_ENTRY
  [ "$DEBUG" == "true" ] && echo FOUND_IPTABLES_ENTRY=$FOUND_IPTABLES_ENTRY
 
  if [ "$FOUND_IPTABLES_ENTRY" == "" ] ; then     
    # not found in iptables. Create Entry:
    $IPTABLES -I INPUT -s $Current_IP -j ACCEPT \
      && echo $Current_IP > $LAST_IP_FILE \
      && echo "$(basename $0): $DYNDNSNAME: iptables new entry added: 'iptables -I INPUT $LINE_NUMBER -s $Current_IP -j ACCEPT'"
  else 
    # found in iptables. Compare Current_IP with Old_IP:

    if [ "$Current_IP" == "$Old_IP" ] ; then
      echo "$(basename $0): $DYNDNSNAME: IP address $Current_IP has not changed"
    else
      LINE_NUMBER=$($IPTABLES -L INPUT --line-numbers -n | grep $Old_IP | awk '{print $1}') \
        && $IPTABLES -D INPUT -s $Old_IP -j ACCEPT
      $IPTABLES -I INPUT $LINE_NUMBER -s $Current_IP -j ACCEPT \
        && echo $Current_IP > $LAST_IP_FILE \
        && echo "$(basename $0): $DYNDNSNAME: iptables have been updated with 'iptables -I INPUT $LINE_NUMBER -s $Current_IP -j ACCEPT'"
    fi
  fi

shift

done

# prepend a rule that accepts all outgoing traffic, if not already present:
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "state RELATED,ESTABLISHED" || $IPTABLES -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# append a reject any, if not already present:
$IPTABLES -L INPUT --line-numbers -n | grep "REJECT" | grep -q "0\.0\.0\.0\/0[ \t]*0\.0\.0\.0\/0" || $IPTABLES -A INPUT -j REJECT --reject-with icmp-host-prohibited

# prepend an allow any from loopback: 
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "127\.0\.0\.0\/8" || $IPTABLES -I INPUT 1 -s 127.0.0.0/8 -j ACCEPT

# Logging example:
# iptables -I INPUT 10 -s 0.0.0.0/0 -j LOG --log-prefix "iptables:REJECT all: "

# DC/OS specific loopback addresses:
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "198\.51\.100\.0\/24" || $IPTABLES -I INPUT 2 -s 198.51.100.0/24 -j ACCEPT
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "44\.128\.0\.0\/20" || $IPTABLES -I INPUT 2 -s 44.128.0.2/20 -j ACCEPT
