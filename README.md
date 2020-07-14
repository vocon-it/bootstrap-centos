# Bootstraping CentOS Machines with tools and Security

```
[ -d bootstrap-centos ] && git clone https://github.com/vocon-it/bootstrap-centos.git
cd bootstrap-centos/
bash 000_all_in_one.sh
```

This project is used for installing basic tools and hardening the security of the machine.
First, it will create a new user named "centos", then configure git, install docker, install jq and yq, set aliases, organize iptables entries, set cronjobs for updating the iptables entries and disable root or password login.
