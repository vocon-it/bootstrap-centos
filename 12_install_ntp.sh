#!/usr/bin/env bash
#
# Install and enable ntp
# see https://vocon-it.atlassian.net/browse/CAAS-1103
#

sudo yum install -y ntp || true
sudo yum install -y chronyd || true # however, it was installed already
sudo systemctl start chronyd || true
sudo systemctl enable chronyd || true
sudo chronyc -a 'burst 4/4'
sudo chronyc -a makestep

echo "Need to reboot now. Wait..."
sleep 5
sudo reboot

