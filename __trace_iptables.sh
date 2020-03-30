#!/bin/bash
#
# Switches on/off tracing of traffic to/from a specific IP address
#
# see also https://vocon-it.com/2020/03/30/tracing-sudo iptables-on-centos-cheat-sheet/
#

if [ $# -gt 1 ]; then
  echo "usage: $0 [<ip-address>|-d]"
  exit 1
fi

# make sure sudo is defined:
which sudo || alias sudo='$@'


echo "BEFORE:"
sudo iptables -t raw -L PREROUTING
sudo iptables -t raw -L OUTPUT

IP=$1

if [ "$IP" == "-d" ]; then
  sudo iptables -t raw -D OUTPUT 1
  sudo iptables -t raw -D OUTPUT 1
  sudo iptables -t raw -D PREROUTING 1
  sudo iptables -t raw -D PREROUTING 1
  echo "tracing is disabled now"
  sudo iptables -t raw -L PREROUTING --line-numbers
  sudo iptables -t raw -L OUTPUT --line-numbers
else
  if [ "$IP" != "" ]; then
    # activate logging:
    modprobe nf_log_ipv4
    sudo sysctl net.netfilter.nf_log.2=nf_log_ipv4
    # modprobe ipt_LOG
    sudo iptables -t raw -I OUTPUT 1 -s $IP/32 -j TRACE
    sudo iptables -t raw -I OUTPUT 1 -d $IP/32 -j TRACE
    sudo iptables -t raw -I PREROUTING 1 -s $IP/32 -j TRACE
    sudo iptables -t raw -I PREROUTING 1 -d $IP/32 -j TRACE

    echo "tracing is enabled now. Check e.g. with # sudo tail -f /var/log/messages | grep TRACE"
  fi
fi

if [ "$IP" != "" ]; then
  echo "AFTER:"
  sudo iptables -t raw -L PREROUTING
  sudo iptables -t raw -L OUTPUT
fi
