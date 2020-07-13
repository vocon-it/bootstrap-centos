#!/bin/sh

CREATEUSER=${CREATEUSER:=centos}
if [ $# -ne 0 ]; then
        echo "usage: [CREATEUSER=myuser] $0"
        echo "       default user is centos"
        exit 1
fi

echo "Creating user $CREATEUSER"

# create user, if it does not exist:
if cut -d: -f1 /etc/passwd | grep -q -E "^${CREATEUSER}$"; then
   echo "User $CREATEUSER exists already"
else
   adduser $CREATEUSER
fi

# initialize the SSH keys, if the authorized_keys is new:
[ -d /home/$CREATEUSER/.ssh ] ||  mkdir -p /home/$CREATEUSER/.ssh
if [ ! -f /home/$CREATEUSER/.ssh/authorized_keys ]; then
   touch /home/$CREATEUSER/.ssh/authorized_keys
   cat /root/.ssh/authorized_keys >> /home/$CREATEUSER/.ssh/authorized_keys
fi

# fix ownership and permissions:
chown -R centos:centos /home/$CREATEUSER/.ssh
chmod 600 /home/$CREATEUSER/.ssh/authorized_keys

# allow user to perform sudo without password, if not already done:
PRIVILEGES=$(cat /etc/sudoers | grep -E "^${CREATEUSER} " | awk '{ $1=""; print}')
[ "$PRIVILEGES" != "" ] \
   && echo "User $CREATEUSER already has following sudo privileges:$PRIVILEGES" \
   || echo "$CREATEUSER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

