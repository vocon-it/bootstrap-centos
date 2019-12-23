#!/bin/sh

if [ "$#" == "0" ]; then
  MY_IP=$(echo $SSH_CLIENT | awk '{ print $1}')
  ADDIP="grodrigues.vocon-it.com ganesh.vocon-it.com vocon-home.mooo.com dev-master1.vocon-it.com dev-node1.vocon-it.com dev-node2.vocon-it.com"
else
  ADDIP="$@"
fi

# update this file from git, if it has changed:
( cd $(dirname $0) && export PATH=$PATH:/usr/local/bin && git pull )

# User input: Add DC/OS IP addresses, if needed 
# (this section is ignored if run via cron):

answer=no
read -t 10 -p "Is this a Kubernetes installation? (no) > " answer
[ "$answer" == "y" -o "$answer" == "yes" ] \
   && echo "Okay, the Kubernetes IP addresses are added to the Firewall table..." \
   && ADDIP="$ADDIP 10.96.0.1"

answer=no
read -t 10 -p "Is this a DC/OS installation? (no) > " answer
[ "$answer" == "y" -o "$answer" == "yes" ] \
   && echo "Okay, the DC/OS IP addresses are added to the Firewall table..." \
   && ADDIP="$ADDIP 195.201.27.175 195.201.17.1 94.130.187.229 195.201.30.230 94.130.186.77"

# run _7xxx.sh:
$(cd $(dirname $0); pwd)/_$(basename $0) $ADDIP

# remove duplicate entries:
$(cd $(dirname $0); pwd)/_7_2_remove_duplicate_iptable_entries.sh
