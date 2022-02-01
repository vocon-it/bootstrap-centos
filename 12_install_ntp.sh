

# see https://vocon-it.atlassian.net/browse/CAAS-1103

sudo yum install -y ntp || true
sudo yum install -y chronyd || true # however, it was installed already
sudo systemctl start chronyd || true
sudo systemctl enable chronyd || true
sudo chronyc -a 'burst 4/4'
sudo chronyc -a makestep
sudo reboot

