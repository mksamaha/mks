#!/bin/bash

apt update -y

apt install grub2 wimtools ntfs-3g -y

#Get the disk size in GB and convert to MB
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))

#Calculate partition size (25% of total size)
part_size_mb=$((disk_size_mb / 4))

#Create GPT partition table
parted /dev/sda --script -- mklabel gpt

#Create two partitions
parted /dev/sda --script -- mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/sda --script -- mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

#Inform kernel of partition table changes
partprobe /dev/sda

sleep 30

partprobe /dev/sda

sleep 30

partprobe /dev/sda

sleep 30 

#Format the partitions
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2

mount /dev/sda1 /mnt

grub-install --boot-directory=/mnt/boot /dev/sda

#Edit GRUB configuration
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
	insmod ntfs
	search --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF


mkdir /media/data
mount /dev/sda2 /media/data

wget -O /media/data/win2016.iso "https://archive.org/download/WS2016X6411636692ViVuOnline/WS_2016_x64_11636692_ViVuOnline.iso"

wget -O /media/data/virtio.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso"

mkdir -p /root/wincd


# Navigate to the windisk directory, or create it if it doesn't exist, and navigate into it
cd /root/windisk || mkdir /root/windisk && cd /root/windisk

# Create a directory named winfile
mkdir -p winfile
echo "Created winfile directory. Press any key to continue..."
read -n 1 -s

# Download Windows 10 ISO
wget -O win10.iso https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409&culture=en-us&country=US
echo "Downloaded win10.iso. Press any key to continue..."
read -n 1 -s

# Mount the ISO to winfile directory
mount -o loop win10.iso winfile
echo "Mounted win10.iso to winfile. Press any key to continue..."
read -n 1 -s

# Synchronize winfile directory content to /mnt
rsync -avz --progress winfile/* /mnt
echo "Synced winfile content to /mnt. Press any key to continue..."
read -n 1 -s

# Unmount the winfile directory
umount winfile
echo "Unmounted winfile. Press any key to continue..."
read -n 1 -s

# Download VirtIO drivers ISO
wget -O virtio.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso
echo "Downloaded virtio.iso. Press any key to continue..."
read -n 1 -s

# Mount the VirtIO drivers ISO to winfile directory
mount -o loop virtio.iso winfile
echo "Mounted virtio.iso to winfile. Press any key to continue..."
read -n 1 -s

# Ensure the target directory exists before synchronization
mkdir -p /mnt/sources/virtio
echo "Ensured /mnt/sources/virtio exists. Press any key to continue..."
read -n 1 -s

# Synchronize VirtIO drivers to the specified directory
rsync -avz --progress winfile/* /mnt/sources/virtio
echo "Synced VirtIO drivers. Press any key to continue..."
read -n 1 -s

# Navigate to the sources directory in /mnt
cd /mnt/sources
echo "Navigated to /mnt/sources. Press any key to continue..."
read -n 1 -s

# Create a cmd.txt file and write the specified command into it
echo "add virtio /virtio_drivers" > cmd.txt
echo "Created and wrote to cmd.txt. Press any key to continue..."
read -n 1 -s

# Update the boot.wim file based on the cmd.txt instructions
wimlib-imagex update boot.wim 2 < cmd.txt
echo "Updated boot.wim. Press any key to continue..."
read -n 1 -s
