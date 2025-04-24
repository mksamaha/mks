#!/bin/bash

set -e
trap 'echo "❌ حدث خطأ في السطر $LINENO. إيقاف السكربت."' ERR

echo "🔧 تحديث النظام وتثبيت الحزم الأساسية..."
apt update -y && apt upgrade -y
apt install grub2 wimtools ntfs-3g rsync wget parted gdisk -y

echo "📏 حساب حجم القرص وتقسيمه..."
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))
part_size_mb=$((disk_size_mb / 4))

parted /dev/sda --script -- mklabel gpt
parted /dev/sda --script -- mkpart primary ntfs 1MiB ${part_size_mb}MiB
parted /dev/sda --script -- mkpart primary ntfs ${part_size_mb}MiB $((2 * part_size_mb))MiB

echo "📡 تحديث جدول الأقسام..."
partprobe /dev/sda
sleep 5

echo "🧹 تهيئة الأقسام..."
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2
echo "✅ تم إنشاء أقسام NTFS."

mount /dev/sda1 /mnt
mkdir -p /root/windisk
mount /dev/sda2 /root/windisk

echo "💡 تثبيت GRUB على القرص..."
grub-install --root-directory=/mnt /dev/sda

echo "📝 إعداد grub.cfg للإقلاع من bootmgr..."
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "windows installer" {
	insmod ntfs
	search --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF

echo "⬇️ تحميل Windows ISO..."
cd /root/windisk
mkdir -p winfile
wget -O win10.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409&culture=en-us&country=US"

echo "💿 تركيب Windows ISO..."
mount -o loop win10.iso winfile
rsync -avz --progress winfile/* /mnt
umount winfile
rm -rf winfile

echo "⬇️ تحميل VirtIO drivers ISO..."
wget -O virtio.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso
mkdir -p winfile
mount -o loop virtio.iso winfile
mkdir -p /mnt/sources/virtio
rsync -avz --progress winfile/* /mnt/sources/virtio
umount winfile

echo "🛠️ تعديل boot.wim لإضافة virtio drivers..."
cd /mnt/sources
if [ -f boot.wim ]; then
  echo "add virtio /virtio_drivers" > cmd.txt
  wimlib-imagex update boot.wim 2 < cmd.txt
else
  echo "⚠️ لم يتم العثور على boot.wim. تخطيت التعديل."
fi

echo "✅ تم تنفيذ كل الخطوات بنجاح. سيتم إعادة التشغيل الآن..."
sleep 5
reboot
