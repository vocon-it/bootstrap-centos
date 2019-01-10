#!/bin/sh

# update this file from git, if it has changed:
( cd $(dirname $0) && export PATH=$PATH:/usr/local/bin && git pull )

# User input: Add DC/OS IP addresses, if needed 
# (this section is ignored if run via cron):
read -t 10 -p "Is this a DC/OS installation? (no) > "
[ "$answer" == "y" -o "$answer" == "yes" ] \
   && echo "Okay, the DC/OS IP addresses are added to the Firewall table..." \
   && ADDIP=" 195.201.27.175 195.201.17.1 94.130.187.229 195.201.30.230 94.130.186.77"

# run _7xxx.sh:
$(cd $(dirname $0); pwd)/_$(basename $0) ganesh.vocon-it.com vocon-home.mooo.com $ADDIP
