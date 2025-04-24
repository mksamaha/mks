#!/bin/bash

set -e

# Handle initramfs-tools issue in Live system
apt-mark hold initramfs-tools || true
dpkg --configure -a || true
apt install -f -y || true

# Update system & install required tools
apt update -y && apt upgrade -y
apt install -y grub2 grub-pc ntfs-3g

# Mount Windows target partition
mount /dev/sda2 /mnt

# Install GRUB to MBR
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/sda

# Copy ISO file to /mnt/iso
mkdir -p /mnt/iso
cp /media/data/win2016.iso /mnt/iso/

# Configure GRUB to boot from ISO
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

# Mount VirtIO ISO for later use
mkdir -p /mnt/sources/virtio
mount -o loop /media/data/virtio.iso /mnt/sources/virtio

# Reboot to start Windows installation
echo "✅ Windows Server 2016 ISO is configured to boot."
echo "Rebooting in 10 seconds..."
sleep 10
reboot
