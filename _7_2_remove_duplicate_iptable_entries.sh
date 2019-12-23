#!/bin/bash

DEBUG=false

suDo(){
  sudo echo hallo >/dev/null 2>&1 && sudo $@ || $@
}

findEntries(){
  # finds iptables entries, if the format is the same as in the output of sudo iptables -S
  # e.g.: findEntries "-A INPUT -s 116.203.105.49/32 -j ACCEPT"
  suDo iptables -S | grep "^$@$"
}

removeDuplicateEntries(){
  # removes all duplicate INPUT and FORWARD entries, except those, which contain " chars (we cannot handle those yet)
  # TODO consider to use following code instead:
  # sudo iptables-save | uniq | sudo iptables-restore # (you might need to restart iptables service after that)

  suDo iptables -S | grep -v "\"" | grep "^-A INPUT\|^-A FORWARD" | while read -r line; do
    [ "$DEBUG" == "true" ] && findEntries "$line"
    echo "Processing $line";
    [ "$DEBUG" == "true" ] && echo $(findEntries "$line" | wc -l)
    while [ $(findEntries "$line" | wc -l) -gt 1 ]; do
      deleteLine="$(echo $line | sed 's/^-A/-D/')"
      [ "$DEBUG" == "true" ] && echo deleteLine=$deleteLine
      suDo iptables "$deleteLine"
      [ "$DEBUG" == "true" ] && findEntries "$line"
    done
  done
}



removeDuplicateEntries
