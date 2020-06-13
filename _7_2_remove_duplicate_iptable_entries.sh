#!/bin/bash
#
# Remove duplicate lines from iptables
#
# for that:
# - iptables-save will be streamed to awk
# - awk will remove excess duplicate lines, but will keep all comments, COMMITs and lines starting with colon
#

# Note: the Procedure can be tested with the function numberOfDuplicateLines:
#       numberOfDuplicateLines should produce "0" if there are no duplicate lines
#       If not, then you might need to add additional patterns that are disregarded in the awk
#       In the moment, only the patterns ^COMMIT, ^: and ^# get special treatment.


#TODO: better replace suDo by alias sudo='$@' in case sudo is not defined 
# sudo echo hello >/dev/null 2>&1 || alias sudo='$@' # but this is to be tested
suDo(){
  sudo echo hallo >/dev/null 2>&1 && sudo $@ || $@
}

numberOfDuplicateLines(){
 suDo iptables-save > /tmp/iptables-save \
   && cat /tmp/iptables-save \
   | awk '/^COMMIT|^:|^#/ {print $0} !/^COMMIT|^:|^#/ && !x[$0]++' > /tmp/iptables-save.awked \
   && diff /tmp/iptables-save.awked /tmp/iptables-save | wc -l
}

if [ "$(numberOfDuplicateLines)" == "0" ]; then
  echo "No duplicate lines found in iptables"
else
  echo "Removing duplicate lines from iptables"
  # debugging:
  [ "$DEBUG" == "true" ] && echo "BEFORE:" && suDo iptables -n -L INPUT
  [ "$DEBUG" == "true" ] && echo "duplicates: " && diff /tmp/iptables-save.awked /tmp/iptables-save
  suDo iptables-save \
    | awk '/^COMMIT|^:|^#/ {print $0} !/^COMMIT|^:|^#/ && !x[$0]++' \
    | suDo iptables-restore \
    && echo "Removed duplicate lines from iptables"
  [ "$?" != "0" ] && echo "failed to remove duplicate lines in iptables" && exit 1 || true
  # debugging:
  [ "$DEBUG" == "true" ] && echo "AFTER:" && suDo iptables -n -L INPUT
fi

