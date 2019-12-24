#!/bin/bash

USAGE="Usage: $0 dyndns-name1 dyndns-name2 ... dyndns-nameN"

#[ "$DYNDNSNAME" == "" ] && DYNDNSNAME=vocon-home.mooo.com
DEBUG=true

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
    Current_IP="$(host $DYNDNSNAME | grep 'address' | cut -f4 -d' ')"
  fi

  [[ ! $Current_IP =~ $re ]] && echo "ERROR: Cannot find IP address for FQDN=$DYNDNSNAME! Exiting ..." &&  exit 1

  # Current_IP
  [ "$DEBUG" == "true" ] && echo Current_IP=$Current_IP

  for CHAIN in INPUT FORWARD; do
    # Old_IP
    [ -e ${LAST_IP_FILE}_$CHAIN ] && Old_IP=$(cat ${LAST_IP_FILE}_$CHAIN) || unset Old_IP
    [ "$DEBUG" == "true" ] && echo Old_IP=$Old_IP
  
    # FOUND_IPTABLES_ENTRY
    [ "$Old_IP" != "" ] && FOUND_IPTABLES_ENTRY="$($IPTABLES -L $CHAIN -n | grep $Old_IP)" || unset FOUND_IPTABLES_ENTRY
    [ "$DEBUG" == "true" ] && echo FOUND_IPTABLES_ENTRY=$FOUND_IPTABLES_ENTRY
   
    if [ "$FOUND_IPTABLES_ENTRY" == "" ] ; then     
      # not found in iptables. Create Entry:
      $IPTABLES -I $CHAIN -s $Current_IP -j ACCEPT \
        && echo $Current_IP > ${LAST_IP_FILE}_$CHAIN \
        && echo "$(basename $0): $DYNDNSNAME: iptables new entry added: 'iptables -I $CHAIN $LINE_NUMBER -s $Current_IP -j ACCEPT'"
    else 
      # found in iptables. Compare Current_IP with Old_IP:
  
      if [ "$Current_IP" == "$Old_IP" ] ; then
        echo "$(basename $0): $DYNDNSNAME: IP address $Current_IP has not changed for CHAIN=$CHAIN"
      else
        # for the case that the same IP address is found more than one time, we remove all occurences (from high to low line number)
        LINE_NUMBERS=$($IPTABLES -L $CHAIN --line-numbers -n | grep $Old_IP | awk '{print $1}') \
          && LINE_NUMBER_LOWEST=$(echo $LINE_NUMBERS | awk '{print $1}') \
          && REVERSE_LINE_NUMBERS=$(echo $LINE_NUMBERS | sed 's/ /\n/g' | tac | tr '\n' ' ') \
          && echo REVERSE_LINE_NUMBERS=$REVERSE_LINE_NUMBERS \
          && for line in $REVERSE_LINE_NUMBERS; do echo removing line $line; $IPTABLES -D $CHAIN $line; done
        # the lowest line number will be replaced by the new IP address:
        $IPTABLES -I $CHAIN $LINE_NUMBER_LOWEST -s $Current_IP -j ACCEPT \
          && echo $Current_IP > ${LAST_IP_FILE}_$CHAIN \
          && echo "$(basename $0): $DYNDNSNAME: iptables have been updated with 'iptables -I $CHAIN $LINE_NUMBER -s $Current_IP -j ACCEPT'"
      fi
    fi
  done

shift

done

# prepend rules that accept traffic from private addresses:
LOCAL_IP_NETWORK_LIST="10.0.0.0/8 192.168.0.0/16"
for LOCAL_IP_NETWORK in $LOCAL_IP_NETWORK_LIST; do
  # echo LOCAL_IP_NETWORK=$LOCAL_IP_NETWORK
  if echo $LOCAL_IP_NETWORK | grep "^[1-9][0-9]\{0,2\}\."; then
    # this is an IPv4 address
    $IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q $LOCAL_IP_NETWORK ||  $IPTABLES -I INPUT 1 -s "$LOCAL_IP_NETWORK" -j ACCEPT
  fi
done

# prepend rules that accept traffic from own addresses:
LOCAL_IP_LIST=$(hostname -I)
for LOCAL_IP in $LOCAL_IP_LIST; do
  # echo LOCAL_IP=$LOCAL_IP
  if echo $LOCAL_IP | grep "^[1-9][0-9]\{0,2\}\."; then
    # this is an IPv4 address
    $IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q $LOCAL_IP ||  $IPTABLES -I INPUT 1 -s "$LOCAL_IP/32" -j ACCEPT
  fi
done

# prepend rules that accepts all incoming web traffic:
#$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "dpt:80 " || $IPTABLES -I INPUT 1 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "dpt:443 " || $IPTABLES -I INPUT 1 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# disable web access:
for CHAIN in INPUT FORWARD; do
  for PORT in 80 443; do

    # find and remove ACCEPT rule for port $PORT:
    unset LINE_NUMBER
    LINE_NUMBER=$($IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep "dpt:$PORT " | head -n 1 | awk '{print $1}')
    [ "$LINE_NUMBER" != "" ] && echo "Removing ACCEPT rule for port ${PORT}" && $IPTABLES -D ${CHAIN} $LINE_NUMBER

    WEAVE_LINE_NUMBER=$($IPTABLES -L ${CHAIN} --line-numbers -n | egrep "^[0-9]+[ ]+WEAVE-" | head -n 1 | awk '{print $1}')
    KUBE_LINE_NUMBER=$($IPTABLES -L ${CHAIN} --line-numbers -n | egrep "^[0-9]+[ ]+KUBE-" | head -n 1 | awk '{print $1}')
    [ "$WEAVE_LINE_NUMBER" == "" ] && DROP_LINE_NUMBER=1 || DROP_LINE_NUMBER="$WEAVE_LINE_NUMBER"
    [ "$KUBE_LINE_NUMBER" == "" ] && [ $KUBE_LINE_NUMBER -lt $DROP_LINE_NUMBER ] && DROP_LINE_NUMBER="$KUBE_LINE_NUMBER"

    if ! $IPTABLES -L ${CHAIN} --line-numbers -n | grep "DROP" | grep -q "dpt:${PORT}$"; then
      echo adding DROP rule for port ${PORT} on ${CHAIN}
      $IPTABLES -I ${CHAIN} $DROP_LINE_NUMBER -p tcp --dport ${PORT} -j DROP
    fi

  done
done

# prepend a rule that accepts all outgoing traffic, if not already present:
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "state RELATED,ESTABLISHED" || $IPTABLES -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# prepend a rule that accepts all traffic from local Docker containers, if not already present:
$IPTABLES -L INPUT   --line-numbers -n | grep "ACCEPT" | grep -q "172.17.0.0/16" || $IPTABLES -I INPUT   -s "172.17.0.0/16" -j ACCEPT
$IPTABLES -L FORWARD --line-numbers -n | grep "ACCEPT" | grep -q "172.17.0.0/16" || $IPTABLES -I FORWARD -s "172.17.0.0/16" -j ACCEPT

# prepend a rule that accepts all traffic from Kubernetes Weave containers, if not already present:
$IPTABLES -L INPUT   --line-numbers -n | grep "ACCEPT" | grep -q "10.44.0.0/16" || $IPTABLES -I INPUT   -s "10.44.0.0/16" -j ACCEPT
$IPTABLES -L FORWARD --line-numbers -n | grep "ACCEPT" | grep -q "10.44.0.0/16" || $IPTABLES -I FORWARD -s "10.44.0.0/16" -j ACCEPT

# append a reject any with logging, if not already present:
if ! $IPTABLES -L INPUT --line-numbers -n | grep "REJECT" | grep -q "0\.0\.0\.0\/0[ \t]*0\.0\.0\.0\/0"; then
   # we filter SSH login attempts without logging:
   $IPTABLES -A INPUT -s 0.0.0.0/0 -p TCP --dport 22 -j REJECT
   # we filter the rest with logging:
   $IPTABLES -A INPUT -s 0.0.0.0/0 -j LOG --log-prefix "iptables:REJECT all: "
   $IPTABLES -A INPUT -j REJECT --reject-with icmp-host-prohibited
fi

# prepend an allow any from loopback: 
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "127\.0\.0\.0\/8" || $IPTABLES -I INPUT 1 -s 127.0.0.0/8 -j ACCEPT

# Logging example:
# iptables -I INPUT 10 -s 0.0.0.0/0 -j LOG --log-prefix "iptables:REJECT all: "

# DC/OS specific loopback addresses:
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "198\.51\.100\.0\/24" || $IPTABLES -I INPUT 2 -s 198.51.100.0/24 -j ACCEPT
$IPTABLES -L INPUT --line-numbers -n | grep "ACCEPT" | grep -q "44\.128\.0\.0\/20" || $IPTABLES -I INPUT 2 -s 44.128.0.2/20 -j ACCEPT
