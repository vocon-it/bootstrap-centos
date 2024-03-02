
[ ! -r ~/.hetzner/u380503.your-storagebox.de.credentials ] \
  && echo "Error: cannot read file ~/.hetzner/u380503.your-storagebox.de.credentials. Exiting..." >&2 \
  && exit 1

if ! grep u380503 /etc/fstab; then
  echo "//u380503.your-storagebox.de/backup /mnt/u380503.your-storagebox.de cifs vers=1.0,iocharset=utf8,rw,credentials=/etc/Hetzner/u380503.your-storagebox.de.credentials,uid=0,gid=1000,file_mode=0660,dir_mode=0770 0 0" \
    | sudo tee -a /etc/fstab
else
  echo "Hetzner Storage Box u380503 is already present in /etc/fstab. Nothing to do."
fi

mount | grep u380503 \
  || sudo mount /mnt/u380503.your-storagebox.de
