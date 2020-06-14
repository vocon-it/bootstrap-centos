#!/bin/sh

# find and apply config file, if present
CONFIG_FILE=${0%.*}.config
[ -r "$CONFIG_FILE" ] \
  && source $CONFIG_FILE \
  && [ "$DEBUG" == "true" ] \
  && echo "$0: read config file $CONFIG_FILE with following content:" \
  && cat $CONFIG_FILE

# DEFAULTS
FIREWALL_UPDATES=${FIREWALL_UPDATES:=true}

# update this file from git, if it has changed:
( cd $(dirname $0) && export PATH=$PATH:/usr/local/bin && git pull )

if [ "$FIREWALL_UPDATES" == "false" ]; then
  echo "Firewall updates are disabled"
  exit 0
fi

if [ "$#" == "0" ]; then
  MY_IP=$(echo $SSH_CLIENT | awk '{ print $1}')
  ADDIP="$MY_IP grodrigues.vocon-it.com ganesh.vocon-it.com vocon-home.mooo.com dev-master1.vocon-it.com dev-node1.vocon-it.com dev-node2.vocon-it.com static.254.247.47.78.clients.your-server.de"
else
  ADDIP="$@"
fi

# is evaluated by _7_create_iptables_entries.sh
export ENABLE_PUBLIC_WEB_ACCESS=false

# User input: Add DC/OS IP addresses, if needed 
# (this section is ignored if run via cron):

answer=no
read -t 10 -p "Is this a Kubernetes installation? (no) > " answer
[ "$answer" == "y" -o "$answer" == "yes" ] \
   && echo "Okay, the Kubernetes IP addresses are added to the Firewall table..." \
   && ADDIP="$ADDIP 10.96.0.1" \
   && export KUBERNETES=true # Note: $KUBERNETES is needed by_7_create_iptables_entries.sh

answer=no
read -t 10 -p "Is this a DC/OS installation? (no) > " answer
[ "$answer" == "y" -o "$answer" == "yes" ] \
   && echo "Okay, the DC/OS IP addresses are added to the Firewall table..." \
   && ADDIP="$ADDIP 195.201.27.175 195.201.17.1 94.130.187.229 195.201.30.230 94.130.186.77" \
   && export DCOS=true # Note: $DCOS is needed by_7_create_iptables_entries.sh

# run _7xxx.sh:
$(cd $(dirname $0); pwd)/_$(basename $0) $ADDIP

# remove duplicate entries:
$(cd $(dirname $0); pwd)/_7_2_remove_duplicate_iptable_entries.sh
