#!/bin/bash

set -e

# Prevent initramfs-tools errors in Live environment
apt-mark hold initramfs-tools || true

# Update system and install required packages
apt update -y && apt upgrade -y
apt install -y parted grub2 grub-pc wimtools ntfs-3g rsync wget curl

# Create GPT partition table on /dev/sda
parted /dev/sda --script mklabel gpt

# Create BIOS Boot Partition (required for GRUB on GPT)
parted /dev/sda --script mkpart primary 1MiB 2MiB
parted /dev/sda --script set 1 bios_grub on

# Create 60GB partition for Windows system
parted /dev/sda --script mkpart primary ntfs 2MiB 61443MiB

# Create partition for data and drivers
parted /dev/sda --script mkpart primary ntfs 61443MiB 100%

# Refresh partition table
partprobe /dev/sda
sleep 5

# Format Windows and data partitions
mkfs.ntfs -f /dev/sda2
mkfs.ntfs -f /dev/sda3

# Mount Windows system partition
mount /dev/sda2 /mnt

# Install GRUB bootloader
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/sda

# Create GRUB configuration file for Windows installer
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Server 2016 Installer" {
    insmod ntfs
    search --no-floppy --set=root --file /bootmgr
    ntldr /bootmgr
    boot
}
EOF

# Mount data partition
mkdir -p /media/data
mount /dev/sda3 /media/data

# Download Windows Server 2016 ISO
wget -O /media/data/win2016.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409"

# Download VirtIO Drivers ISO
wget -O /media/data/virtio.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso"

# Mount and copy Windows files
mkdir -p /root/wincd
mount -o loop /media/data/win2016.iso /root/wincd
rsync -avh --progress /root/wincd/ /mnt
umount /root/wincd

# Mount VirtIO drivers to make them accessible during installation
mkdir -p /mnt/sources/virtio
mount -o loop /media/data/virtio.iso /mnt/sources/virtio

# Optional: automatic reboot after 10 seconds
echo "✅ Setup complete. Rebooting in 10 seconds..."
sleep 10
reboot
