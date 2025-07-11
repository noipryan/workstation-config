scp -r swainrl@10.2.192.159:~/.ssh ~/

scp -r swainrl@10.2.192.159:~/workstation-config ~/

dnf install -y arch-install-scripts 

blkid -o value -s UUID /dev/vda3

# create etc folder
sudo mkdir -p /mnt/etc
 
# generate fstab file
genfstab -U /mnt |  tee /mnt/etc/fstab
  
# Edit the fstab file and remove the zram entry
vim /etc/fstab


# Bootstrap the OS
dnf --installroot=/mnt --releasever=42 --setopt=fastestmirror=True install -y @core --use-host-config

cd /mnt


scp -r swainrl@10.2.192.159:/etc/default/grub /mnt/etc/default/grub

bd6e6a1f-6f16-4a61-a885-2195934779bd
GRUB_ENABLE_CRYPTODISK=y

# remove etc/resolv.conf symlink for bind mount
rm -f etc/resolv.conf
 
# touch resolv.conf file
touch etc/resolv.conf
 
# mount the filesystems
for f in dev etc/resolv.conf proc sys sys/firmware/efi/efivars; do
  mount --bind /$f $f
done

# chroot into the new installation
sudo chroot /mnt /bin/bash
 
# update the system
dnf --releasever=42 --setopt=fastestmirror=True --refresh update

dnf --releasever=42 --setopt=fastestmirror=True install -y \
  @core \
  @standard \
  @hardware-support \
  langpacks-{en,tr}* \
  glibc-all-langpacks \
  kernel{,-core,-devel,-modules,-modules-extra,-headers} \
  vim-enhanced \
  git \
  ansible \
  grub2-efi-x64-* \
  shim-* \
  efibootmgr

# set the timezone (replace Europe/Istanbul with your timezone)
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
 
#~ set the locale (replace en_US.UTF-8 with your locale)
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
 
#~ set the vconsole (replace us with your keymap)
echo 'KEYMAP=us' > /etc/vconsole.conf
echo 'FONT=eurlatgr' >> /etc/vconsole.conf
 
#~ set hostname
echo 'fedora-bootstrap' > /etc/hostname

# install grub2
grub2-install --target=x86_64-efi --boot-directory=/boot --efi-directory=/boot/efi --bootloader-id=FEDORA --force

# run dracut
dracut --force --regenerate-all --verbose

grub2-mkconfig -o /boot/grub2/grub.cfg