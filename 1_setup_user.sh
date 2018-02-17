#!/bin/sh

if [ $# -ne 1 ]; then
    echo "usage: $0 USER"
    exit 1
fi

USER=$1

# create user, if it does not exist:
cut -d: -f1 /etc/passwd | grep -q -E "^${USER}$" \
    && echo "User $USER exists already" \
    || adduser $USER

# allow user to perform sudo without password, if not already done:
PRIVILEGES=$(cat /etc/sudoers | grep -E "^${USER} " | awk '{ $1=""; print}')
[ "$PRIVILEGES" != "" ] \
    && echo "User $USER already has following sudo privileges:$PRIVILEGES" \
    || echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
