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
    return 1
  fi

  for CHAIN in $@; do
    # Create the chain, if it does not exist:
    if ! sudo $IPTABLES -n -L $CHAIN 2>/dev/null 1>/dev/null; then
      sudo $IPTABLES -N $CHAIN && echo "$CHAIN created" || return 1
    fi
  done
}

modify_iptable_chain_policy() {
  definitions

  if [ $# -le 1 ]; then
    echo "usage: $0 POLICY CHAIN_1 [CHAIN_2 ...]" 
    return 1
  fi

  POLICY=$1
  shift
  CHAINS=$@

  for CHAIN in $CHAINS; do
    # set default policy:
    if [ "$POLICY" == "DROP" -o "$POLICY" == "ACCEPT" ] \
    && [ "$CHAIN" == "INPUT" -o "$CHAIN" == "FORWARD" -o "$CHAIN" == "OUTPUT" ]; then
      # default CHAIN policy in case of DROP and ACCEPT and built-in chain, add policy, if not already present
      $IPTABLES -S "$CHAIN" | head -1 | egrep -q -v "^-P $CHAIN $POLICY$" \
        && sudo $IPTABLES -P $CHAIN $POLICY || return 1 && echo "default policy ${POLICY} added to $CHAIN"
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
  echo IPTABLES=$IPTABLES
  CHAIN=${CHAIN:=NOT_DEFINED}
  INSERT_AT_LINE_NUMBER=${INSERT_AT_LINE_NUMBER:=1}
  JUMP=${JUMP:=NOT_DEFINED}
  [ "$CHAIN" == "NOT_DEFINED" ] && echo "CHAIN is not defined. Exiting..." && usage && return 1
  [ "$JUMP" == "NOT_DEFINED" ] && echo "JUMP is not defined. Exiting..." && usage && return 1
  EXIT_CODE=1

  if [ "$INSERT_AT_LINE_NUMBER" == "0" ]; then
    # check, if the current chain has an explicit policy rule:
    $IPTABLES -S $CHAIN | tail -n 1 | egrep -q "^-A $CHAIN -j " && INSERT_AT_LINE_NUMBER="$(expr $($IPTABLES -S $CHAIN | wc -l) - 1)"
    if [ "$INSERT_AT_LINE_NUMBER" != "0" ]; then
      # line number has changed;
      [ "$DEBUG" == "true" ] && echo "INSERT_AT_LINE_NUMBER has changed: $INSERT_AT_LINE_NUMBER"
      insertTargetAtLineNumberIfNeeded && return 0 || return 1
    fi
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
    return 1
  fi
}

is_rule_present() {
  definitions
  # usage: $0 <rule-in-S-notation>
  #        returns true or false
  __CHAIN=$(echo $RULE | awk '{print $2}')
  $IPTABLES -S $__CHAIN | egrep -q "^$(echo $@ | sed 's_-_\\-_g')$"
}

#-----------------
# manual test of is_rule_present()
#RULE="-A  CUSTOM-ACCEPT -s 192.168.0.0/16 -j ACCEPT"
#is_rule_present $RULE && echo rule is present
#exit 0
#-----------------

update_iptables_chain() {
  # 
  # update of a chain based on a <chain>.config file
  #   the file can contain domain names instead of IP addresses.
  #   if this functin is called periodically, it is made sure that the DNS to IP address binding is kept up to date
  #

  usage() {
    echo "usage: $0: ${FUNCNAME[1]} <chain>" 
    echo "       file with name <chain>.config must exist"
  }

  # Definition of internal variables:
  IPTABLES=${IPTABLES:=/usr/sbin/iptables}
  __CHAIN=$1
  __CONFIG_FILE=$(dirname $0)/${__CHAIN}.config

  # Input validation
  [ "$#" != "1" ] && usage && return 1
  [ ! -r "${__CONFIG_FILE}" ] && echo "File ${__CONFIG_FILE} not found on $(pwd)" && return 1

  [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: Chain ${__CHAIN} has follwing config"
  [ "$DEBUG" == "true" ] && cat ${__CONFIG_FILE}

  # create/flush TEMP-CHAIN chain
  $IPTABLES -N TEMP-CHAIN 2>/dev/null
  $IPTABLES -F TEMP-CHAIN 
  
  # number or rules for plausibility:
  NUMBER_OF_CONFIG_LINES=$(cat "${__CONFIG_FILE}" | grep -c '\-j')
  [ "$NUMBER_OF_CONFIG_LINES" == "0" ] && echo "$0: ${FUNCNAME[0]}: No configuration found. Returning..." && return 1

  # create TEMP-CHAIN rules from ${__CONFIG_FILE} file:
  cat ${__CONFIG_FILE} \
    | envsubst \
    | egrep -v "^#" \
    | egrep -v "^[ ]*$" \
    | awk -F '-A [^ ]* ' '{print $2}' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'  \
    | xargs -L 1 $IPTABLES -A TEMP-CHAIN
  # export TEMP-CHAIN chain to ${__CONFIG_FILE}.resolved file
  $IPTABLES -S TEMP-CHAIN | sed "s/TEMP-CHAIN/${__CHAIN}/g" > ${__CONFIG_FILE}.resolved 

  # Plausibility check:
  NUMBER_OF_CONFIG_LINES_UPDATED=$(cat "${__CONFIG_FILE}.resolved" | grep -c '\-j')
  [ "$NUMBER_OF_CONFIG_LINES" != "$NUMBER_OF_CONFIG_LINES_UPDATED" ] && echo "Only $NUMBER_OF_CONFIG_LINES_UPDATED of all config lines ($NUMBER_OF_CONFIG_LINES) were successful. Therefore the chain will not be updated at all. Returning..." && return 1

  # save current ${__CHAIN} rules to a file, so it can be compared to the updated version
  $IPTABLES -S ${__CHAIN} > ${__CHAIN}.save; 

  if ! diff ${__CHAIN}.save ${__CONFIG_FILE}.resolved >/dev/null; then
    # files are different; therefore the chain must be replaced by the resolved version of the configured chain
    $IPTABLES -F ${__CHAIN} \
      && cat ${__CONFIG_FILE}.resolved | xargs -L 1 $IPTABLES
      echo "$0: ${FUNCNAME[0]}: iptables chain ${__CHAIN} updated"
      [ "$DEBUG" == "true" ] && $IPTABLES -S ${__CHAIN}
  else
    [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: iptables chain $CHAIN and the FQDNs therein have not changed"
  fi
  [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: iptables chain $CHAIN content after update:"
  [ "$DEBUG" == "true" ] && $IPTABLES -S $CHAIN


  # cleaning
  $IPTABLES -F TEMP-CHAIN; $IPTABLES -X TEMP-CHAIN
}

#-----------------
# manual test of update_iptables_chain()
#create_iptable_chains CUSTOM-FORWARD-HEAD
#update_iptables_chain CUSTOM-FORWARD-HEAD
#exit 0
#-----------------

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
#modify_iptable_chain_policy RETURN CUSTOM-ACCEPT CUSTOM-DROP

#############
# Add CUSTOM-ACCEPT at line 1 of INPUT and FORWARD chains:
#############
# TODO: decide, if we need different CUSTOM-ACCEPT chains for INPUT and FORWARD chains
#############
for CHAIN in INPUT; do
#for CHAIN in FORWARD INPUT; do
  JUMP=CUSTOM-ACCEPT; INSERT_AT_LINE_NUMBER=1
  insertTargetAtLineNumberIfNeeded
done

#############
# Add CUSTOM-DROP at line 2 of INPUT and FORWARD chains:
#############
# TODO: decide, if we need different CUSTOM-DROP chains for INPUT and FORWARD chains
#############
for CHAIN in INPUT; do
#for CHAIN in FORWARD INPUT; do
  JUMP=CUSTOM-DROP; INSERT_AT_LINE_NUMBER=2
  insertTargetAtLineNumberIfNeeded
done

update_iptables_chain CUSTOM-ACCEPT
update_iptables_chain CUSTOM-DROP

#############
# CUSTOM-TAIL of INPUT for Logging
#############
create_iptable_chains CUSTOM-TAIL
update_iptables_chain CUSTOM-TAIL

# Append to INPUT chain:
INSERT_AT_LINE_NUMBER=0; CHAIN=INPUT; JUMP=CUSTOM-TAIL; insertTargetAtLineNumberIfNeeded
 
#############
# Default ACCEPT policy on INPUT chain
#############
modify_iptable_chain_policy ACCEPT INPUT

#############
# CUSTOM-FORWARD-HEAD for securing the FORWARD chain
#############
create_iptable_chains CUSTOM-FORWARD-HEAD
update_iptables_chain CUSTOM-FORWARD-HEAD

# Prepend to FORWARD chain:
INSERT_AT_LINE_NUMBER=1; CHAIN=FORWARD; JUMP=CUSTOM-FORWARD-HEAD; insertTargetAtLineNumberIfNeeded
 
