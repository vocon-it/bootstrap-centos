#!/bin/sh

if [ $# -eq 0 ]; then
    USER=centos
else 
    if [ $# -eq 1 ]; then
        USER=$1
    else
        echo "usage: $0 [USER]"
        echo "       default user is centos"
        exit 1
    fi
fi

echo "Creating user $USER"

# create user, if it does not exist:
if cut -d: -f1 /etc/passwd | grep -q -E "^${USER}$"; then
   echo "User $USER exists already" 
else
   adduser $USER
fi

# initialize the SSH keys, if the authorized_keys is new:
[ -d /home/$USER/.ssh ] ||  mkdir -p /home/$USER/.ssh
if [ ! -f /home/$USER/.ssh/authorized_keys ]; then
   touch /home/$USER/.ssh/authorized_keys
   cat /root/.ssh/authorized_keys >> /home/$USER/.ssh/authorized_keys
fi

# fix ownership and permissions:
chown -R centos:centos /home/$USER/.ssh
chmod 600 /home/$USER/.ssh/authorized_keys

# allow user to perform sudo without password, if not already done:
PRIVILEGES=$(cat /etc/sudoers | grep -E "^${USER} " | awk '{ $1=""; print}')
[ "$PRIVILEGES" != "" ] \
   && echo "User $USER already has following sudo privileges:$PRIVILEGES" \
   || echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers


