#!/bin/bash

set -e

# Mark initramfs-tools on hold to prevent errors in Live mode
apt-mark hold initramfs-tools || true
dpkg --configure -a || true
apt install -f -y || true

# Ensure required packages are installed
apt update -y && apt upgrade -y
apt install -y parted grub2 grub-pc ntfs-3g

# Recreate partitions (optional if already created)
parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart primary 1MiB 2MiB
parted /dev/sda --script set 1 bios_grub on
parted /dev/sda --script mkpart primary ntfs 2MiB 61443MiB
parted /dev/sda --script mkpart primary ntfs 61443MiB 100%

partprobe /dev/sda
sleep 5

# Format only system and data partitions
mkfs.ntfs -f /dev/sda2
mkfs.ntfs -f /dev/sda3

# Mount system partition
mount /dev/sda2 /mnt

# Install GRUB bootloader to /dev/sda
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/sda

# Prepare ISO directory and move ISO there if not already done
mkdir -p /mnt/iso
if [ ! -f /mnt/iso/win2016.iso ]; then
  cp /media/data/win2016.iso /mnt/iso/
fi

# Write GRUB configuration to boot from ISO
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Server 2016 ISO Boot" {
    insmod ntfs
    insmod loopback
    insmod iso9660
    search --no-floppy --set=root --file /iso/win2016.iso
    loopback loop /iso/win2016.iso
    ntldr (loop)/bootmgr
}
EOF

# Mount VirtIO for installer access (already downloaded)
mkdir -p /mnt/sources/virtio
mount -o loop /media/data/virtio.iso /mnt/sources/virtio

# Done
echo " ISO and GRUB configured. Rebooting in 10 seconds..."
sleep 10
reboot
