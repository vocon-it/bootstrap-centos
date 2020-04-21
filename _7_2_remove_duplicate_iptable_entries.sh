#!/bin/bash

# Remove duplicate lines from iptables
#
# for that:
# - iptables-save will be streamed to awk
# - awk will remove excess duplicate lines, but will keep all comments, COMMITs and lines starting with colon
#

# Procedure can be tested with following command (should produce an empty diff, of there are no duplicate lines!):

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
  suDo iptables-save \
    | awk '/^COMMIT|^:|^#/ {print $0} !/^COMMIT|^:|^#/ && !x[$0]++' \
    | suDo iptables-restore \
    && echo "Removed duplicate lines from iptables"
  [ "$?" != "0" ] && echo "failed to remove duplicate lines in iptables" && exit 1 || true
fi

exit 0


DEBUG=true

# New way of removing duplicate line in the iptabels config:
iptables-save \
  | awk '/^COMMIT|^:|^#/ {print $0} !/^COMMIT|^:|^#/ && !x[$0]++' \
  | iptables-restore



exit 0


# OLD:



findEntries(){
  # finds iptables entries, if the format is the same as in the output of sudo iptables -S
  # e.g.: findEntries "-A INPUT -s 116.203.105.49/32 -j ACCEPT"
  suDo iptables -S | grep "^$@$"
}

removeDuplicateEntries(){
  # removes all duplicate INPUT and FORWARD entries, except those, which contain " chars (we cannot handle those yet)
  # TODO consider to use following code instead:
  # sudo iptables-save | uniq | sudo iptables-restore # (you might need to restart iptables service after that)

  suDo iptables -S | grep -v "\"" | grep "^-A INPUT\|^-A FORWARD\|^-A CUSTOM-ACCEPT\|^-A CUSTOM-DROP" | while read -r line; do
    [ "$DEBUG" == "true" ] && findEntries "$line"
    echo "Processing $line";
    [ "$DEBUG" == "true" ] && echo "found $(findEntries "$line" | wc -l) entries for $line"
    while [ $(findEntries "$line" | wc -l) -gt 1 ]; do
      deleteLine="$(echo $line | sed 's/^-A/-D/')"
      [ "$DEBUG" == "true" ] && echo deleteLine=$deleteLine
      suDo iptables "$deleteLine" && echo "applied following command successfully : iptables $deleteLine" || echo "error applying following command: iptables $deleteLine"
      [ "$DEBUG" == "true" ] && findEntries "$line"
    done
  done
}



removeDuplicateEntries
