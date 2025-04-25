
umount /dev/sda1 || true
mkfs.ntfs -f /dev/sda1


mount /dev/sda1 /mnt

sudo mkdir -p /media/data
mount /dev/sda2 /media/data

mount /dev/sda1 /mnt

apt update
apt install grub-pc -y
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

sudo mkdir -p /media/data
mount /dev/sda2 /media/data

mkdir -p /root/wincd
mount -o loop /media/data/win10.iso /root/wincd
rsync -avz --progress /root/wincd/* /mnt
umount /root/wincd


mount /dev/sda1 /mnt
mkdir -p /mnt/sources/virtio
mount -o loop /media/data/virtio.iso /mnt/sources/virtio

sudo apt update
sudo apt install wimtools -y


touch cmd.txt
echo 'add /mnt/sources/virtio /virtio' >> cmd.txt
wimlib-imagex update /mnt/sources/boot.wim 2 < cmd.txt

reboot
