# Bootstraping CentOS Machines with tools and Security

## TODO

- [ ] Automate custom prompt (see below, "Set Custom Prompt")

## Bootstrap
```
curl -s https://raw.githubusercontent.com/vocon-it/bootstrap-centos/develop/2_update-git-centos.sh | bash -
[ -d bootstrap-centos ] || git clone https://github.com/vocon-it/bootstrap-centos.git
cd bootstrap-centos/
bash 000_all_in_one.sh
```

This project is used for installing basic tools and hardening the security of the machine.
First, it will create a new user named "centos", then configure git, install docker, install jq and yq, set aliases, organize iptables entries, set cronjobs for updating the iptables entries and disable root or password login.

## Set Custom Prompt

```shell script
cat <<EOF | sudo tee /etc/profile.d/custom.sh
export ENVIRONMENT=PROD
export PS1="\${ENVIRONMENT} \[\033[0;32m\]\u@$(hostname): \[\033[36m\]\W\[\033[0m\] \n\$ "
EOF
```