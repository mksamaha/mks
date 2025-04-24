sudo su

apt update

apt install -y gparted filezilla grub2 wimtools gdisk rsync wget curl
umount /dev/sda* || true
wipefs -a /dev/sda
fdisk /dev/sda

o
n
p
1
+60000M
t
1
7


n
p
2
enter
enter
t
2
7
w

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

mount -o loop /media/data/win2016.iso /root/wincd

rsync -avz --progress /root/wincd/* /mnt

umount /root/wincd

mount /dev/sda1 /mnt

mkdir -p /mnt/sources/virtio

mount -o loop /media/data/virtio.iso /mnt/sources/virtio

sudo apt update

sudo apt install wimtools -y

cd /mnt/sources

touch cmd.txt

echo 'add /mnt/sources/virtio /virtio' > cmd.txt

wimlib-imagex update /mnt/sources/boot.wim 2 < cmd.txt
