#!/bin/bash
#
# Add dynamic and static IP addresses to the Firewall
#
# Concept:
# - all ACCEPT rules are placed into a CUSTOM-ACCEPT chain
# - CUSTOM-ACCEPT chain has a last entry to RETURN to the calling chain
# - CUSTOM-ACCEPT is placed as line #1 of INPUT and FORWARD chains
# - most of the DROP rulse are placed into CUSTOM-DROP chain
# - CUSTOM-DROP chain has a last entry to RETURN to the calling chain
# - CUSTOM-DROP is placed as line #2 of the FORWARD chain
# - some REJECT and LOG rules are still placed at the end of INPUT chain
# TODO: will we keep some REJECT and LOG rules at the end of the INPUT chain?


# In case iptables is not in the path, we need to use the full path:
definitions(){
  IPTABLES=${IPTABLES:=/usr/sbin/iptables}
  sudo echo hello 2>/dev/null 1>/dev/null || alias sudo='$@'
}


create_iptable_chains(){
  definitions

  if [ $# -le 0 ]; then
    echo "usage: $0 CHAIN_1 [CHAIN_2 ...]"
    exit 1
  fi

  for CHAIN in $@; do
    # Create the chain, if it does not exist:
    if ! sudo $IPTABLES -n -L $CHAIN 2>/dev/null 1>/dev/null; then
      sudo $IPTABLES -N $CHAIN && echo "$CHAIN created" || exit 1
    fi
  done
}

modify_iptable_chain_policy() {
  definitions

  if [ $# -le 1 ]; then
    echo "usage: $0 POLICY CHAIN_1 [CHAIN_2 ...]" 
    exit 1
  fi

  POLICY=$1
  shift
  CHAINS=$@

  for CHAIN in $CHAINS; do
    # set default policy:
    if [ "$POLICY" == "DROP" -o "$POLICY" == "ACCEPT" ] \
    && [ "$CHAIN" == "INPUT" -o "$CHAIN" == "FORWARD" -o "$CHAIN" == "OUTPUT" ]; then
      # default CHAIN policy in case of DROP and ACCEPT and built-in chain
      sudo $IPTABLES -P $CHAIN $POLICY || exit 1 && echo "default policy ${POLICY} added to $CHAIN"
    elif ! sudo $IPTABLES -n -L $CHAIN | egrep -q "^${POLICY}[ ]+"; then
      sudo $IPTABLES -A $CHAIN -j ${POLICY} && echo "default policy ${POLICY} added to $CHAIN as explicit rule"
    fi
  done
}

# Insert a rule at position $INSERT_AT_LINE_NUMBER, if it is not found at that place:
insertTargetAtLineNumberIfNeeded() {
  usage() {
    echo "usage: [IPTABLES=...;] [INSERT_AT_LINE_NUMBER=...;] CHAIN=...; JUMP=...; $0"
    echo "INSERT_AT_LINE_NUMBER=0 means 'at the last line'"
  }

  clean_from_lower_line_duplicates() {
    # clean $CHAIN from ${JUMP} duplicates found on lower line numbers (up to 3 duplicates)
    for i in $(seq 1 3); do
      if [ $($IPTABLES -n -L $CHAIN | egrep -c "^${JUMP}[ ]+all[ -]+0.0.0.0/0[ ]+0.0.0.0/0[ ]+$") -gt 1 ]; then
        [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: found duplicate entry; deleting: $IPTABLES -D $CHAIN -j ${JUMP}"
        $IPTABLES -D $CHAIN -j ${JUMP}
      else
        break
      fi
    done
  }

  IPTABLES=${IPTABLES:=/usr/sbin/iptables}
  CHAIN=${CHAIN:=NOT_DEFINED}
  INSERT_AT_LINE_NUMBER=${INSERT_AT_LINE_NUMBER:=1}
  JUMP=${JUMP:=NOT_DEFINED}
  [ "$CHAIN" == "NOT_DEFINED" ] && echo "CHAIN is not defined. Exiting..." && usage && exit 1
  [ "$JUMP" == "NOT_DEFINED" ] && echo "JUMP is not defined. Exiting..." && usage && exit 1
  EXIT_CODE=1

  if [ "$INSERT_AT_LINE_NUMBER" == "0" ]; then
    # exit function, if rule exists at the last linie already:
    if $IPTABLES -n -L ${CHAIN} --line-numbers \
       | tail -n 1 | egrep -q "^[0-9]+[ ]*${JUMP}"; then
       [ "$DEBUG" == "true" ] && echo "iptables rule exists already"
       clean_from_lower_line_duplicates
       return
    else
      # create the entry
      [ "$DEBUG" == "true" ] && echo "Appending entry: $IPTABLES -A ${CHAIN} -j ${JUMP}"
      $IPTABLES -A ${CHAIN} -j ${JUMP} && EXIT_CODE=0
      clean_from_lower_line_duplicates
    fi

  elif [ $INSERT_AT_LINE_NUMBER -gt 0 ]; then
    # exit function, if rule exists on specified line number already:
    if $IPTABLES -n -L ${CHAIN} --line-numbers \
       | egrep -q "^${INSERT_AT_LINE_NUMBER}[ ]*${JUMP}"; then
       [ "$DEBUG" == "true" ] && echo "iptables rule exists already: $IPTABLES -I ${CHAIN} ${INSERT_AT_LINE_NUMBER} -j ${JUMP}"
       return
    fi
    # create the entry
    [ "$DEBUG" == "true" ] && echo "Inserting entry at line: $IPTABLES -I ${CHAIN} ${INSERT_AT_LINE_NUMBER} -j ${JUMP}"
    $IPTABLES -I ${CHAIN} ${INSERT_AT_LINE_NUMBER} -j ${JUMP} && EXIT_CODE=0
  fi

  # evaluate the success:
  if [ "$EXIT_CODE" == "1" ]; then
    echo "$0: Failed to apply following command: $@"
    exit 1
  fi


}

####################
#      MAIN        #
####################

# for logging:
date

definitions

if [ "$(id -u)" != "0" ]; then
  echo "This script ($0) must be run as root. Exiting..."
  exit 1
fi

if [ "$#" == "0" ]; then
  echo "usage: $0 dyndns-name1 dyndns-name2 ... dyndns-nameN"
  exit 1
fi

#############
# make sure sudo is defined (create an alias, if needed)
#############
sudo echo hello 2>/dev/null 1>/dev/null || alias sudo='$@'

#############
# Install bind-utils if not present:
#############
sudo yum list installed | grep -q bind-utils || sudo yum install -y bind-utils


#############
# Create CUSTOM-ACCEPT and CUSTOM-DROP chains, if not present and set the default policy to "RETURN":
#############
create_iptable_chains CUSTOM-ACCEPT CUSTOM-DROP 
modify_iptable_chain_policy RETURN CUSTOM-ACCEPT CUSTOM-DROP

#############
# Add CUSTOM-ACCEPT at line 1 of INPUT and FORWARD chains:
#############
# TODO: decide, if we need different CUSTOM-ACCEPT chains for INPUT and FORWARD chains
#############
for CHAIN in FORWARD INPUT; do
  JUMP=CUSTOM-ACCEPT; INSERT_AT_LINE_NUMBER=1
  insertTargetAtLineNumberIfNeeded
done

#############
# Add CUSTOM-DROP at line 2 of INPUT and FORWARD chains:
#############
# TODO: decide, if we need different CUSTOM-DROP chains for INPUT and FORWARD chains
#############
for CHAIN in FORWARD INPUT; do
  JUMP=CUSTOM-DROP; INSERT_AT_LINE_NUMBER=2
  insertTargetAtLineNumberIfNeeded
done

#############
# Add static accepted networks
#############
for CHAIN in CUSTOM-ACCEPT; do
  # prepend a rule that accepts all outgoing traffic, if not already present:
  $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q "state RELATED,ESTABLISHED" || $IPTABLES -I ${CHAIN} 1 -m state --state RELATED,ESTABLISHED -j ACCEPT

  # prepend a rule that accepts all traffic from local Docker containers, if not already present:
  $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q "172.17.0.0/16" || $IPTABLES -I ${CHAIN} 1  -s "172.17.0.0/16" -j ACCEPT

  # prepend an allow any from loopback:
  $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q "127\.0\.0\.0\/8" || $IPTABLES -I ${CHAIN} 1 -s 127.0.0.0/8 -j ACCEPT

  # prepend rules that accept traffic from private addresses:
  LOCAL_IP_NETWORK_LIST="10.0.0.0/8 192.168.0.0/16"
  for LOCAL_IP_NETWORK in $LOCAL_IP_NETWORK_LIST; do
    [ "$DEBUG" == "true" ] && echo LOCAL_IP_NETWORK=$LOCAL_IP_NETWORK
    if echo $LOCAL_IP_NETWORK | grep "^[1-9][0-9]\{0,2\}\."; then
      # $LOCAL_IP_NETWORK is an IPv4 network and will be added, if not already present:
      $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q $LOCAL_IP_NETWORK ||  $IPTABLES -I ${CHAIN} 1 -s "$LOCAL_IP_NETWORK" -j ACCEPT
    fi
  done

  # prepend rules that accept traffic from own addresses:
  LOCAL_IP_LIST=$(hostname -I)
  for LOCAL_IP in $LOCAL_IP_LIST; do
    # echo LOCAL_IP=$LOCAL_IP
    if echo $LOCAL_IP | grep "^[1-9][0-9]\{0,2\}\."; then
      # $LOCAL_IP is an IPv4 address and will be added, if not already present:
      $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q $LOCAL_IP ||  $IPTABLES -I ${CHAIN} 1 -s "$LOCAL_IP/32" -j ACCEPT
    fi
  done

  # prepend a rule that accepts all traffic from Kubernetes Weave containers, if not already present:
  if [ "$KUBERNETES" == "true" ]; then
    $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q "10.32.0.0/12" || $IPTABLES -I ${CHAIN} 1  -s "10.32.0.0/12" -j ACCEPT
  fi

  # Prepend rules for DC/OS specific loopback addresses, if not already present:
  if [ "$DCOS" == "true" ]; then
    $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q "198\.51\.100\.0\/24" || $IPTABLES -I ${CHAIN} 1 -s 198.51.100.0/24 -j ACCEPT
    $IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep -q "44\.128\.0\.0\/20" || $IPTABLES -I ${CHAIN} 1 -s 44.128.0.2/20 -j ACCEPT
  fi
done

#############
# DYNAMIC ACCEPTED FQDNs OR IP ADDRESSES
#############
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

  for CHAIN in CUSTOM-ACCEPT; do
    # Old_IP
    [ -e ${LAST_IP_FILE}_$CHAIN ] && Old_IP=$(cat ${LAST_IP_FILE}_$CHAIN) || unset Old_IP
    [ "$DEBUG" == "true" ] && echo Old_IP=$Old_IP

    # FOUND_IPTABLES_ENTRY
    [ "$Old_IP" != "" ] && FOUND_IPTABLES_ENTRY="$($IPTABLES -L $CHAIN -n | grep $Old_IP)" || unset FOUND_IPTABLES_ENTRY
    [ "$DEBUG" == "true" ] && echo FOUND_IPTABLES_ENTRY=$FOUND_IPTABLES_ENTRY

    if [ "$FOUND_IPTABLES_ENTRY" == "" ] ; then
      # not found in iptables. Create Entry:
      # TODO: which ACTION is needed in the CUSTOM chains?
#      [ "$(echo $CHAIN | cut -5)" == "CUSTOM" ] && ACTION=RETURN || ACTION=ACCEPT
      ACTION=ACCEPT
      $IPTABLES -I $CHAIN -s $Current_IP -j $ACTION \
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


#############
# Control Web Access and VNC Access
############
# TODO: if ENABLE_PUBLIC_WEB_ACCESS=true, we need to act on VNC separately.
#       better create a function that can be called with 80, 443, 5901 and 6901?
############
if [ "ENABLE_PUBLIC_WEB_ACCESS" == "true" ]; then
  # enable web access (commented out, because we do not allow web traffic for now):
  $IPTABLES -L CUSTOM-ACCEPT --line-numbers -n | grep "ACCEPT" | grep -q "dpt:80 " || $IPTABLES -I CUSTOM-ACCEPT 1 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
  $IPTABLES -L CUSTOM-ACCEPT --line-numbers -n | grep "ACCEPT" | grep -q "dpt:443 " || $IPTABLES -I CUSTOM-ACCEPT 1 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
else
  # disable web access:
  REJECTED_PORTS="80 443 5901 6901 5902 6902"

  # remove ACCEPT rules if they exist:
  for CHAIN in INPUT FORWARD CUSTOM-ACCEPT CUSTOM-DROP; do
    for PORT in $REJECTED_PORTS; do

      # find and remove ACCEPT rule for port $PORT, if present:
      unset LINE_NUMBER
      LINE_NUMBER=$($IPTABLES -L ${CHAIN} --line-numbers -n | grep "ACCEPT" | grep "dpt:$PORT " | head -n 1 | awk '{print $1}')
      [ "$LINE_NUMBER" != "" ] && echo "Removing ACCEPT rule for port ${PORT}" && $IPTABLES -D ${CHAIN} $LINE_NUMBER

    done
  done

  # add DROP rules, if they do not exist:
  for CHAIN in CUSTOM-DROP; do
    for PORT in $REJECTED_PORTS; do
      DROP_LINE_NUMBER=1

      # Add DROP rule for port $PORT, if not present:
      if ! $IPTABLES -L ${CHAIN} --line-numbers -n | grep "DROP" | grep -q "dpt:${PORT}$"; then
        echo adding DROP rule for port ${PORT} on ${CHAIN}
        $IPTABLES -I ${CHAIN} $DROP_LINE_NUMBER -p tcp --dport ${PORT} -j DROP
      fi

    done
  done
fi

#############
# CUSTOM-TAIL of INPUT for Logging
#############
CHAIN=CUSTOM-TAIL
create_iptable_chains $CHAIN

# filter SSH login attempts without logging:
if ! $IPTABLES -n -L $CHAIN --line-numbers | egrep "DROP[ ]+tcp[ -]+0.0.0.0/0[ ]+0.0.0.0/0[ ]+tcp[ ]+dpt:22"; then
  [ "$DEBUG" == "true" ] && echo "$0: Adding filter for SSH" 
  $IPTABLES -A $CHAIN -s 0.0.0.0/0 -p TCP --dport 22 -j DROP
fi

# Log all other traffic:
if ! $IPTABLES -n -L $CHAIN --line-numbers | egrep -q "LOG[ ]+all[ -]+0.0.0.0/0[ ]+0.0.0.0/0[ ]+LOG"; then
   # we log the rest:
  [ "$DEBUG" == "true" ] && echo "$0: Adding Log entry" 
   $IPTABLES -A $CHAIN -s 0.0.0.0/0 -j LOG --log-prefix "iptables: DROP any: "
fi

# Append to INPUT chain:
INSERT_AT_LINE_NUMBER=0; CHAIN=INPUT; JUMP=CUSTOM-TAIL; insertTargetAtLineNumberIfNeeded
 
#############
# Default DROP policy on INPUT chain
#############
modify_iptable_chain_policy DROP INPUT


