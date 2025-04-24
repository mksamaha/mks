apt update -y && apt upgrade -y
apt install parted grub2 grub-pc wimtools ntfs-3g -y

# Create GPT partition table
parted /dev/sda --script mklabel gpt

# Create BIOS Boot Partition (1MiB, required for GRUB on GPT)
parted /dev/sda --script mkpart primary 1MiB 2MiB
parted /dev/sda --script set 1 bios_grub on

# Create 60GB partition for Windows files
parted /dev/sda --script mkpart primary ntfs 2MiB 61443MiB

# Create a second NTFS partition for ISO and driver storage (remaining space)
parted /dev/sda --script mkpart primary ntfs 61443MiB 100%

# Inform the kernel about partition changes
partprobe /dev/sda
sleep 10
partprobe /dev/sda
sleep 10

# Format the partitions (skip the BIOS Boot Partition)
mkfs.ntfs -f /dev/sda2
mkfs.ntfs -f /dev/sda3

# Mount the first NTFS partition for boot files
mount /dev/sda2 /mnt

# Install GRUB for BIOS systems using GPT
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/sda

# Create GRUB boot menu for Windows Installer
mkdir -p /mnt/boot/grub
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "Windows Installer" {
    insmod ntfs
    search --set=root --file=/bootmgr
    ntldr /bootmgr
    boot
}
EOF

# Prepare mount point for ISO storage
mkdir /media/data
mount /dev/sda3 /media/data

# Download Windows Server 2012 ISO and VirtIO drivers ISO
wget -O /media/data/win2012.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195443&clcid=0x409&culture=en-us&country=US"
wget -O /media/data/virtio.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso"

# Mount Windows ISO and copy its content to the boot partition
mkdir -p /root/wincd
mount -o loop /media/data/win2016.iso /root/wincd
rsync -avz --progress /root/wincd/* /mnt
umount /root/wincd

mkdir -p /mnt/sources/virtio
mount -o loop /media/data/virtio.iso /mnt/sources/virtio

sudo apt install wimtools -y

cd /mnt/sources

touch cmd.txt


echo 'add /mnt/sources/virtio /virtio' >> cmd.txt

wimlib-imagex update /mnt/sources/boot.wim 2 < cmd.txt

