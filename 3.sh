#!/bin/bash

set -e

# Fix initramfs-tools issue in Debian Live (no kernel in /boot)
apt-mark hold initramfs-tools || true
dpkg --configure -a || true
apt install -f -y || true

# Update and install required packages
apt update -y && apt upgrade -y
apt install -y parted grub2 grub-pc ntfs-3g wget curl

# Create GPT partition table on /dev/sda
parted /dev/sda --script mklabel gpt

# Create BIOS Boot Partition
parted /dev/sda --script mkpart primary 1MiB 2MiB
parted /dev/sda --script set 1 bios_grub on

# Create 60GB partition for Windows
parted /dev/sda --script mkpart primary ntfs 2MiB 61443MiB

# Create partition for ISO and drivers
parted /dev/sda --script mkpart primary ntfs 61443MiB 100%

# Reload partition table
partprobe /dev/sda
sleep 5

# Format partitions
mkfs.ntfs -f /dev/sda2
mkfs.ntfs -f /dev/sda3

# Mount system partition
mount /dev/sda2 /mnt

# Install GRUB bootloader
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/sda

# Create GRUB config to boot ISO
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

# Mount data partition
mkdir -p /media/data
mount /dev/sda3 /media/data

# Download Windows Server 2016 ISO
mkdir -p /mnt/iso
wget -O /mnt/iso/win2016.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409"

# Download VirtIO drivers
wget -O /media/data/virtio.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso"

# Mount VirtIO ISO for later use during installation
mkdir -p /mnt/sources/virtio
mount -o loop /media/data/virtio.iso /mnt/sources/virtio

# Final message and reboot
echo " Windows Server 2016 ISO is ready to boot."
echo "Rebooting in 10 seconds..."
sleep 10
reboot
