#!/bin/bash

set -e

# Fix initramfs-tools issue in Debian Live (no kernel in /boot)
apt-mark hold initramfs-tools || true
dpkg --configure -a || true
apt install -f -y || true

# Update and install required packages
apt update -y && apt upgrade -y
apt install -y parted grub2 grub-pc wimtools ntfs-3g rsync wget curl

# Create GPT partition table on /dev/sda
parted /dev/sda --script mklabel gpt

# Create BIOS Boot Partition (GRUB needs this on GPT)
parted /dev/sda --script mkpart primary 1MiB 2MiB
parted /dev/sda --script set 1 bios_grub on

# Create 60GB partition for Windows system
parted /dev/sda --script mkpart primary ntfs 2MiB 61443MiB

# Create partition for ISO and drivers
parted /dev/sda --script mkpart primary ntfs 61443MiB 100%

# Reload partition table
partprobe /dev/sda
sleep 5

# Format the system and data partitions
mkfs.ntfs -f /dev/sda2
mkfs.ntfs -f /dev/sda3

# Mount Windows system partition
mount /dev/sda2 /mnt

# Install GRUB bootloader to MBR
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/sda

# Write GRUB config to boot Windows ISO
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Server 2016 Installer" {
    insmod ntfs
    search --no-floppy --set=root --file /bootmgr
    ntldr /bootmgr
    boot
}
EOF

# Mount ISO/data partition
mkdir -p /media/data
mount /dev/sda3 /media/data

# Download Windows Server 2016 ISO
wget -O /media/data/win2016.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409"

# Download VirtIO drivers ISO
wget -O /media/data/virtio.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso"

# Mount and copy Windows setup files
mkdir -p /root/wincd
mount -o loop /media/data/win2016.iso /root/wincd
rsync -avh --progress /root/wincd/ /mnt
umount /root/wincd

# Mount VirtIO drivers for setup
mkdir -p /mnt/sources/virtio
mount -o loop /media/data/virtio.iso /mnt/sources/virtio

# Final message and reboot prompt
echo "✅ Windows Server 2016 setup is ready!"
echo "Rebooting in 10 seconds to begin installation..."
sleep 10
reboot
