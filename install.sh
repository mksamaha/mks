#!/bin/bash

set -e
trap 'echo "An error occurred at line $LINENO. Exiting script." >&2' ERR

echo "Updating system and installing required packages..."
apt update -y && apt upgrade -y

# Install only the essential packages without initramfs-tools
apt install --no-install-recommends grub-pc grub2-common parted gdisk ntfs-3g wget rsync wimtools -y

echo "Calculating disk size and creating partitions..."
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))
part_size_mb=$((disk_size_mb / 4))

parted /dev/sda --script -- mklabel gpt
parted /dev/sda --script -- mkpart primary ntfs 1MiB ${part_size_mb}MiB
parted /dev/sda --script -- mkpart primary ntfs ${part_size_mb}MiB $((2 * part_size_mb))MiB

echo "Refreshing partition table..."
partprobe /dev/sda
sleep 5

echo "Formatting partitions..."
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2
echo "Partitions formatted as NTFS."

mount /dev/sda1 /mnt
mkdir -p /root/windisk
mount /dev/sda2 /root/windisk

echo "Installing GRUB bootloader..."
grub-install --root-directory=/mnt /dev/sda

echo "Creating grub.cfg for Windows boot..."
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Installer" {
	insmod ntfs
	search --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF

echo "Downloading Windows ISO..."
cd /root/windisk
mkdir -p winfile
wget -O win10.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409&culture=en-us&country=US"

echo "Mounting Windows ISO and copying files..."
mount -o loop win10.iso winfile
rsync -avz --progress winfile/* /mnt
umount winfile
rm -rf winfile

echo "Downloading VirtIO drivers ISO..."
wget -O virtio.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso
mkdir -p winfile
mount -o loop virtio.iso winfile
mkdir -p /mnt/sources/virtio
rsync -avz --progress winfile/* /mnt/sources/virtio
umount winfile
rm -rf winfile

echo "Modifying boot.wim with VirtIO drivers (if available)..."
cd /mnt/sources
if [ -f boot.wim ]; then
  echo "add virtio /virtio_drivers" > cmd.txt
  wimlib-imagex update boot.wim 2 < cmd.txt
else
  echo "boot.wim not found. Skipping modification."
fi

echo "All tasks completed successfully. Rebooting in 10 seconds..."
sleep 10
reboot
