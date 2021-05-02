#!/bin/sh
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

# for logging:
date

# update this file from git, if it has changed:
( cd $(dirname $0) && export PATH=$PATH:/usr/local/bin && git pull )

definitions(){
  IPTABLES=${IPTABLES:=/usr/sbin/iptables}
  sudo echo hello 2>/dev/null 1>/dev/null || alias sudo='$@'
}

create_iptables_chains(){
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
insert_rule_at_line() {
  usage() {
    echo "usage: [IPTABLES=...;] [INSERT_AT_LINE_NUMBER=...;] CHAIN=...; JUMP=...; ${FUNCNAME[1]}"
    echo "       ${FUNCNAME[1]} CHAIN INSERT_AT_LINE_NUMBER JUMP"
    echo
    echo "       Note: INSERT_AT_LINE_NUMBER=0 means 'at the last line'"
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

  clean() {
    unset CHAIN CHAINS INSERT_AT_LINE_NUMBER
  }

  clean_return() {
    clean
    return $1
  }

  IPTABLES=${IPTABLES:=/usr/sbin/iptables}

  if [ "$#" == "0" ]; then
    CHAIN=${CHAIN:=NOT_DEFINED}
    INSERT_AT_LINE_NUMBER=${INSERT_AT_LINE_NUMBER:=1}
    JUMP=${JUMP:=NOT_DEFINED}
  elif [ "$#" == "3" ]; then
    CHAIN=$1
    INSERT_AT_LINE_NUMBER=$2
    JUMP=$3
  else
    usage
    clean && return 1
  fi
  [ "$CHAIN" == "NOT_DEFINED" ] && echo "CHAIN is not defined. Exiting..." && usage && clean && return 1
  [ "$JUMP" == "NOT_DEFINED" ] && echo "JUMP is not defined. Exiting..." && usage && clean && return 1
  EXIT_CODE=1

  [ "$DEBUG" == "true" ] && echo -e "$0: ${FUNCNAME[0]}:\nIPTABLES=$IPTABLES\nCHAIN=$CHAIN\nINSERT_AT_LINE_NUMBER=$INSERT_AT_LINE_NUMBER\nJUMP=$JUMP"

  if [ "$INSERT_AT_LINE_NUMBER" == "0" ]; then
    # check, if the current chain has an explicit policy rule:
    $IPTABLES -S $CHAIN | tail -n 1 | egrep -q "^-A $CHAIN -j " && INSERT_AT_LINE_NUMBER="$(expr $($IPTABLES -S $CHAIN | wc -l) - 1)"
    if [ "$INSERT_AT_LINE_NUMBER" != "0" ]; then
      # line number has changed;
      [ "$DEBUG" == "true" ] && echo "INSERT_AT_LINE_NUMBER has changed: $INSERT_AT_LINE_NUMBER"
      insert_rule_at_line && return 0 || return 1
    fi
    # exit function, if rule exists at the last linie already:
    if $IPTABLES -n -L ${CHAIN} --line-numbers \
       | tail -n 1 | egrep -q "^[0-9]+[ ]*${JUMP}"; then
       [ "$DEBUG" == "true" ] && echo "iptables rule exists already"
       clean_from_lower_line_duplicates
       clean && return 0
    else
      # create the entry
      [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: Appending entry: $IPTABLES -A ${CHAIN} -j ${JUMP}"
      $IPTABLES -A ${CHAIN} -j ${JUMP} && EXIT_CODE=0
      clean_from_lower_line_duplicates
    fi

  elif [ $INSERT_AT_LINE_NUMBER -gt 0 ]; then
    # exit function, if rule exists on specified line number already:
    if $IPTABLES -n -L ${CHAIN} --line-numbers \
       | egrep -q "^${INSERT_AT_LINE_NUMBER}[ ]*${JUMP}"; then
       [ "$DEBUG" == "true" ] && echo "iptables rule exists already: $IPTABLES -I ${CHAIN} ${INSERT_AT_LINE_NUMBER} -j ${JUMP}"
       clean
       return 0
    fi
    # create the entry
    [ "$DEBUG" == "true" ] && echo "Inserting entry at line: $IPTABLES -I ${CHAIN} ${INSERT_AT_LINE_NUMBER} -j ${JUMP}"
    $IPTABLES -I ${CHAIN} ${INSERT_AT_LINE_NUMBER} -j ${JUMP} && EXIT_CODE=0
  fi

  # evaluate the success:
  if [ "$EXIT_CODE" == "1" ]; then
    echo "$0: ${FUNCNAME[0]}: Failed to apply following command: ${FUNCNAME[0]} $@"
    clean && return 1
  fi

  clean && return 0
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

update_iptables_chains() {
  for __CHAIN in $@; do
    update_iptables_chain $__CHAIN
  done
  unset __CHAIN
}

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
  
  import_chain() {
    __IMPORT_FILE=$1
    __TARGET_CHAIN=$2

    $IPTABLES -N $__TARGET_CHAIN >/dev/null
    $IPTABLES -F $__TARGET_CHAIN

    __INPUT_LINE_NUMBER=0
    __OVERALL_SUCCESS=true
    while read LINE; do
      __LINE_SUCCESS=true
      __INPUT_LINE_NUMBER=$(expr $__INPUT_LINE_NUMBER + 1)

      # filter iptables command:
      CMD=$(echo $LINE \
              | sed "s/^[ ]*\(-[A-Z]\)[ ]\{1,\}[^ ]\{1,\}[ ]\{1,\}/\1 ${__TARGET_CHAIN} /" \
              | egrep -v "^[ ]*#" \
              | egrep -v "^[ ]*-N" \
              | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
              | egrep -v "^[ ]*$" )

      # run command, if not empty:
      if [ "$CMD" != "" ]; then
        echo "$CMD" | xargs $IPTABLES \
          || __LINE_SUCCESS=false
      fi

      # Log warning, if iptables command was not successful:
      [ "$__LINE_SUCCESS" != "true" ] \
             && echo "$0: ${FUNCNAME[0]}: ERROR on input file ${__IMPORT_FILE} line number $__INPUT_LINE_NUMBER: $LINE" \
             && __OVERALL_SUCCESS=false
    done <"${__IMPORT_FILE}"
    
#    if [ "$DEBUG" == "true" ]; then
      [ "$__OVERALL_SUCCESS" == "true" ] \
        && echo "$0: ${FUNCNAME[1]}: iptables chain ${__TARGET_CHAIN} updated successfully" \
        || echo "$0: ${FUNCNAME[1]}: iptables chain ${__TARGET_CHAIN} updated with errors"
#    fi

    [ "$__OVERALL_SUCCESS" == "true" ] && return 0 || return 1
  }

  copy_chain() {
    __SOURCE_CHAIN=$1
    __TARGET_CHAIN=$2

    # export __SOURCE_CHAIN to temp file:
    $IPTABLES -S $__SOURCE_CHAIN | sed "s/$__SOURCE_CHAIN/$__TARGET_CHAIN/g" > "/tmp/$__SOURCE_CHAIN.save"
    cat "/tmp/$__SOURCE_CHAIN.save"

    import_chain "/tmp/$__SOURCE_CHAIN.save" "${__TARGET_CHAIN}"

  }

  # Definition of internal variables:
  IPTABLES=${IPTABLES:=/usr/sbin/iptables}
  __CHAIN=$1
  __CONFIG_DIR=${CONFIG_DIR:=$(echo ${0%.*} | sed 's_\([^/]*$\)_.\1_')}
  __CONFIG_FILE=${__CHAIN}.config
  __TMP=${TMP:=/tmp}

  # Input validation
  [ "$#" != "1" ] && echo "ERROR: wrong number of arguments ($# instead of 1)" && usage && return 1
  [ ! -r "${__CONFIG_DIR}/${__CONFIG_FILE}" ] && echo "File ${__CONFIG_DIR}/${__CONFIG_FILE} not found on $(pwd)" && return 1

  [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: Chain ${__CHAIN} has follwing config"
  [ "$DEBUG" == "true" ] && cat ${__CONFIG_DIR}/${__CONFIG_FILE}

  # create/flush TEMP-CHAIN chain
  $IPTABLES -N TEMP-CHAIN 2>/dev/null
  $IPTABLES -F TEMP-CHAIN

  # number or rules for plausibility:
  NUMBER_OF_CONFIG_LINES=$(cat "${__CONFIG_DIR}/${__CONFIG_FILE}" | egrep -v "^#" | egrep -v "^[ ]*$" | grep -c '\-j')
  [ "$NUMBER_OF_CONFIG_LINES" == "0" ] && echo "$0: ${FUNCNAME[0]}: No configuration found. Returning..." && return 1

  # create TEMP-CHAIN iptables chain from rules found on the config file ${__CONFIG_DIR}/${__CONFIG_FILE}:
  # will ignore comment lines
  import_chain "${__CONFIG_DIR}/${__CONFIG_FILE}" TEMP-CHAIN

  # export TEMP-CHAIN chain to ${__CONFIG_DIR}/${__CONFIG_FILE}.resolved file
  $IPTABLES -S TEMP-CHAIN | sed "s/TEMP-CHAIN/${__CHAIN}/g" > "${__TMP}/${__CONFIG_FILE}.resolved"

  # save current ${__CHAIN} rules to a file, so it can be compared to the updated version
  $IPTABLES -S ${__CHAIN} > "${__TMP}/${__CHAIN}.save";

  if ! diff "${__TMP}/${__CHAIN}.save" "${__TMP}/${__CONFIG_FILE}.resolved" >/dev/null; then
    # files are different; therefore the chain must be replaced by the resolved version of the configured chain
    $IPTABLES -F ${__CHAIN} \
      && echo "xxxxxxxxxxxxxxxx" \
      && copy_chain TEMP-CHAIN ${__CHAIN} \
      && echo "$0: ${FUNCNAME[0]}: iptables chain ${__CHAIN} updated" \
      || echo "$0: ${FUNCNAME[0]}: failed to update chain ${__CHAIN}"
      [ "$DEBUG" == "true" ] && $IPTABLES -S ${__CHAIN}
  else
    [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: iptables chain $CHAIN and the FQDNs therein have not changed"
  fi
  [ "$DEBUG" == "true" ] && echo "$0: ${FUNCNAME[0]}: iptables chain $CHAIN content after update:"
  [ "$DEBUG" == "true" ] && $IPTABLES -S $CHAIN


  # cleaning
  $IPTABLES -F TEMP-CHAIN; $IPTABLES -X TEMP-CHAIN
}

test_update_iptables_chain() {
  # manual test of update_iptables_chain()
  definitions
  
  create_iptables_chains GGG
  
  cat <<EOF > .7_create_iptables_entries/GGG.config
# example comment and then example with -N
-N CUSTOM--ACCEPT

# example append rule with stahic network:
#-A CUSTOM--ACCEPT -j ACCEPT -s khfk127.0.0.0/8 -m comment --comment "LOCAL_IP_NETWORK"
-A CUSTOM--ACCEPT -j ACCEPT -s 127.0.0.0/8 -m comment --comment "LOCAL IP NETWORK"
EOF

  [ "$1" == fail ] && echo -A CUSTOM--ACCEPT -j ACCEPT -s khfk127.0.0.0/8 -m comment --comment "LOCAL_IP_NETWORK" >> .7_create_iptables_entries/GGG.config
  
  update_iptables_chains GGG
  
  $IPTABLES -S GGG
  rm .7_create_iptables_entries/GGG.config
}

test_suite_update_iptables_chain() {
  # manual test of update_iptables_chain()
  definitions
  #$IPTABLES -F GGG; $IPTABLES -X GGG
  echo "successful test: <----------------"
  echo "expected: one line starting with -N and one line starting with -A"
  test_update_iptables_chain
  echo "second successful test: <----------------"
  echo "expected: one line starting with -N and one line starting with -A"
  test_update_iptables_chain
  echo "failed test: <----------------"
  echo "expected: still one line starting with -N and one line starting with -A"
  test_update_iptables_chain fail
  echo "exiting ... <----------------"
}

# test_suite_update_iptables_chain
# exit 0

numberOfDuplicateLines(){
 sudo iptables-save > /tmp/iptables-save \
   && cat /tmp/iptables-save \
   | awk '/^COMMIT|^:|^#/ {print $0} !/^COMMIT|^:|^#/ && !x[$0]++' > /tmp/iptables-save.awked \
   && diff /tmp/iptables-save.awked /tmp/iptables-save | wc -l
}

remove_duplicate_entries_from_iptables() {

  if [ "$(numberOfDuplicateLines)" == "0" ]; then
    echo "No duplicate lines found in iptables"
  else
    echo "Removing duplicate lines from iptables"
    # debugging:
    [ "$DEBUG" == "true" ] && echo "BEFORE:" && sudo iptables -n -L INPUT
    [ "$DEBUG" == "true" ] && echo "duplicates: " && diff /tmp/iptables-save.awked /tmp/iptables-save
    sudo iptables-save \
      | awk '/^COMMIT|^:|^#/ {print $0} !/^COMMIT|^:|^#/ && !x[$0]++' \
      | sudo iptables-restore \
      && echo "Removed duplicate lines from iptables"
    [ "$?" != "0" ] && echo "failed to remove duplicate lines in iptables" && exit 1 || true
    # debugging:
    [ "$DEBUG" == "true" ] && echo "AFTER:" && sudo iptables -n -L INPUT
  fi

}

my_local_ipv4_addresses() {
  __IPV4_ADDRESSES=
  for LOCAL_IP in $(hostname -I); do
    if echo $LOCAL_IP | grep -q "^[1-9][0-9]\{0,2\}\."; then
      # $LOCAL_IP is an IPv4 address and will be added, if not already present:
      __IPV4_ADDRESSES="$__IPV4_ADDRESSES $LOCAL_IP"
    fi
  done
  echo $__IPV4_ADDRESSES
  unset __IPV4_ADDRESSES
}

add_local_ip_addresses() {
  __CONFIG_DIR=${CONFIG_DIR:=$(echo ${0%.*} | sed 's_\([^/]*$\)_.\1_')}
  __LOCAL_TEMP_CONFIG="${__CONFIG_DIR}/CUSTOM-LOCAL.config.temp"
  __LOCAL_CONFIG="${__CONFIG_DIR}/CUSTOM-LOCAL.config"

  #echo "-N CUSTOM-LOCAL" > "${__LOCAL_TEMP_CONFIG}"
  cat <<EOF > "${__LOCAL_TEMP_CONFIG}"
-N CUSTOM-LOCAL
-A CUSTOM-ACCEPT -j ACCEPT -s 127.0.0.0/8 -m comment --comment "LOCAL_IP_NETWORK"
-A CUSTOM-ACCEPT -j ACCEPT -s 192.168.0.0/16 -m comment --comment "LOCAL_IP_NETWORK"
-A CUSTOM-ACCEPT -j ACCEPT -s 10.0.0.0/8 -m comment --comment "LOCAL_IP_NETWORK"
EOF
  for IP in $(my_local_ipv4_addresses); do
    echo "-A CUSTOM-LOCAL -j ACCEPT -s ${IP}/32 -m comment --comment \"LOCAL_IP_NETWORK\"" >> "${__LOCAL_TEMP_CONFIG}"
  done
  cat "${__LOCAL_TEMP_CONFIG}"
  mv "${__LOCAL_TEMP_CONFIG}" "${__LOCAL_CONFIG}"
}

#-----------------
# manual test of my_local_ipv4_addresses()
#my_local_ipv4_addresses
#exit 0
#-----------------

####################
#      MAIN        #
####################

if [ "$(id -u)" != "0" ]; then
  echo "This script ($0) must be run as root. Exiting..."
  exit 1
fi

usage(){
  echo "usage: $0"
}

if [ "$#" != "0" ]; then
  usage
  exit 1
fi

#############
# find and apply config file, if present
#############
CONFIG_DIR=${CONFIG_DIR:=$(echo ${0%.*} | sed 's_\([^/]*$\)_.\1_')}
CONFIG_FILE=$CONFIG_DIR/config
#$(echo ${0%.*} | sed 's_/\([^/]*$\)_/.\1_')/config
[ -r "$CONFIG_FILE" ] \
  && source $CONFIG_FILE \
  && [ "$DEBUG" == "true" ] \
  && echo "$0: read config file $CONFIG_FILE with following content:" \
  && cat $CONFIG_FILE

# DEFAULTS
ENABLED=${ENABLED:=true}
definitions

#############
# Exit, if function is disabled
#############
if [ "$ENABLED" == "false" ]; then
  echo "Firewall updates are disabled"
  exit 0
fi

#############
# Add local IP addresses
#############
add_local_ip_addresses

#############
# Add current SSH IP address to list of allowed IP addresses (does not work in the moment, since we do not allow for adding config lines programmatically any more)
#############
# TODO: create a function to re-write *.config files
#############
## Adapt List of IP addresses / FQDNs to be allowed by firewall rules:
#if [ "$#" == "0" ]; then
#  # programm is called with no arguments
#  MY_IP=$(echo $SSH_CLIENT | awk '{ print $1}')
#  # prepend your own SSH source IP, if present:
#  export ADDIP="$MY_IP $ADDIP"
#else
#  # program is called with arguments; use those arguments only
#  ADDIP="$@"
#fi

#############
# Install bind-utils if not present:
#############
sudo yum list installed | grep -q bind-utils || sudo yum install -y bind-utils

#############
# Add INPUT rules
#############
create_iptables_chains CUSTOM-ACCEPT CUSTOM-DROP CUSTOM-TAIL CUSTOM-LOCAL
update_iptables_chains CUSTOM-ACCEPT CUSTOM-DROP CUSTOM-TAIL CUSTOM-LOCAL
insert_rule_at_line INPUT 1 CUSTOM-LOCAL
insert_rule_at_line INPUT 2 CUSTOM-ACCEPT
insert_rule_at_line INPUT 3 CUSTOM-DROP
insert_rule_at_line INPUT 0 CUSTOM-TAIL

#############
# Add FORWARD rules
#############
create_iptables_chains CUSTOM-FORWARD-HEAD
update_iptables_chains CUSTOM-FORWARD-HEAD
insert_rule_at_line FORWARD 1 CUSTOM-FORWARD-HEAD

#############
# Default ACCEPT policy on INPUT chain
#############
modify_iptable_chain_policy ACCEPT INPUT

#############
# remove duplicate entries form iptables
#############
remove_duplicate_entries_from_iptables

echo done
