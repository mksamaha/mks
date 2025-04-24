apt update -y && apt upgrade -y
apt install parted grub2 wimtools ntfs-3g -y

parted /dev/sda --script mklabel gpt

parted /dev/sda --script mkpart primary ntfs 1MiB 61441MiB

parted /dev/sda --script mkpart primary ntfs 61441MiB 100%

partprobe /dev/sda
sleep 10
partprobe /dev/sda
sleep 10

mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2

mount /dev/sda1 /mnt
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/sda

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
