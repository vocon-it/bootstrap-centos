
#write out current crontab
crontab -l > mycron

#echo new cron into cron file
NEWJOB="* * * * * /root/bootstrap-centos/7_create_iptables_entries.sh > /tmp/update-firewall.log 2>&1" 

if ! crontab -l | grep "$NEWJOB" ; then
   echo "$NEWJOB" >> mycron

   #install new cron file
   crontab mycron
   echo "Installed Job '$NEWJOB'"
else
   echo "Job was installed already"
fi

# cleaning
rm mycron
