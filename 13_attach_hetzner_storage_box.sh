
sudo yum install -y cifs-utils

HETZNER_STORAGE_USER=u380503
sudo mkdir -p /mnt/${HETZNER_STORAGE_USER}.your-storagebox.de
sudo mkdir -p /etc/Hetzner/
sudo touch /etc/Hetzner/${HETZNER_STORAGE_USER}.your-storagebox.de.credentials
sudo chmod 600 /etc/Hetzner/${HETZNER_STORAGE_USER}.your-storagebox.de.credentials

sudo cat /etc/Hetzner/${HETZNER_STORAGE_USER}.your-storagebox.de.credentials | grep -q username=${HETZNER_STORAGE_USER} \
  || CREDENTIALS_FOUND=false

[ "${CREDENTIALS_FOUND}" == "false" ] \
  && echo "ERROR: cannot read file /etc/Hetzner/${HETZNER_STORAGE_USER}.your-storagebox.de.credentials or the file does not contain the username=${HETZNER_STORAGE_USER}. Exiting..." \
  && exit 1

if ! grep -q ${HETZNER_STORAGE_USER} /etc/fstab; then
  echo "//${HETZNER_STORAGE_USER}.your-storagebox.de/backup /mnt/${HETZNER_STORAGE_USER}.your-storagebox.de cifs vers=1.0,iocharset=utf8,rw,credentials=/etc/Hetzner/${HETZNER_STORAGE_USER}.your-storagebox.de.credentials,uid=1000,gid=1000,file_mode=0660,dir_mode=0770 0 0" \
    | sudo tee -a /etc/fstab
else
  echo "INFO: Hetzner Storage Box ${HETZNER_STORAGE_USER} is already present in /etc/fstab. Nothing to do."
fi

if mount | grep -q ${HETZNER_STORAGE_USER}; then
  echo "INFO: /mnt/${HETZNER_STORAGE_USER}.your-storagebox.de is already mounted. Nothing to do."
else
  sudo mount /mnt/${HETZNER_STORAGE_USER}.your-storagebox.de \
    && echo "INFO: mounted /mnt/${HETZNER_STORAGE_USER}.your-storagebox.de" \
    || echo "ERROR: failed to mount  /mnt/${HETZNER_STORAGE_USER}.your-storagebox.de"
fi
