MY_IP=$(ifconfig eth0 | grep 'inet ' | awk '{print $2}')
iptables -I FORWARD 1 -p tcp -s ${MY_IP} -d 10.0.0.0/8 -j ACCEPT
iptables -I FORWARD 2 -p tcp -s ${MY_IP} --dport 80 -j DROP

# view:
iptables -S FORWARD
