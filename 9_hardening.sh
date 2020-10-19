#!/bin/sh

if [ "$(cat ~/.hardened)" == "true" ]; then
  echo "System is hardened already. Nothing to do"
else
  read -p 'Be careful! This script will disallow any password login and any root login! Proceed? (no)' answer 
  
  [ "$answer" != "y" -a "$answer" != "yes" ] && echo "Aborting..." && exit 0 
  
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
  
  # disallow login with password and disallow SSH root login:
  for SETTING in ChallengeResponseAuthentication PasswordAuthentication PermitRootLogin; do
     cat /etc/ssh/sshd_config | grep -v '^#' | grep $SETTING | grep yes \
     && sed -i "s/^[ ]*\($SETTING\).*/\1 no/g" /etc/ssh/sshd_config
  
     echo changed to:
     cat /etc/ssh/sshd_config | grep -v '^#' | grep $SETTING
  done
  
  for SETTING in UsePAM; do
     cat /etc/ssh/sshd_config | grep -v '^#' | grep $SETTING | grep no \
     && sed -i "s/^[ ]*\($SETTING\).*/\1 yes/g" /etc/ssh/sshd_config
  
     echo changed to:
     cat /etc/ssh/sshd_config | grep -v '^#' | grep $SETTING
  done
  
  systemctl reload sshd
  
  read -p "Please test now, whether an SSH connection as non-privileged user and 'sudo su -' is (still) possible. Everything working? (no)> " answer
  
  if [ "$answer" != "y" -a "$answer" != "yes" ]; then
    echo rolling back
    cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    systemctl reload sshd
    echo done rolling back
  else
    echo true > ~/.hardened
  fi
fi
