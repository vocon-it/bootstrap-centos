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

## Set Custom Prompt on PROD

```shell script
cat <<EOF | sudo tee /etc/profile.d/custom.sh

export ENVIRONMENT=PROD
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
export PS1="${ENVIRONMENT} "'\[\e[1;32m\]\u@\h \[\e[1;33m\]\w \[\e[1;34m\]$(parse_git_branch)\[\e[00m\]\n$ '
EOF
```
Note: you need to manually change the ENVIRONMENT value to match your environment.