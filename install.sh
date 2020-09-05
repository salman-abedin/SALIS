#!/bin/sh

#Update the system clock
timedatectl set-ntp true

################################################################################
#                             User Info
################################################################################

printf "User Name: "
read -r uName

printf "Root Password: "
read -r rPass

printf "Server Address? (Press 'Enter' If you live in Bangladesh): "
read -r SERVER

################################################################################
#                             Partioning & Mounting
################################################################################

lsblk

printf "Device Letter? (Be careful!): "
read -r device

printf "Root Partition Digit? (Be careful!): "
read -r root

root=/dev/sd$device$root
yes | mkfs.ext4 "$root"
mount "$root" /mnt

################################################################################
#                             Base Packages & Firmware Installation
################################################################################

echo "Server = ${SERVER:-http://mirror.xeonbd.com/archlinux/\$repo/os/\$arch}" \
   > /etc/pacman.d/mirrorlist
pacstrap /mnt --noconfirm base base-devel linux-zen linux-firmware

################################################################################
#                             Configuration
################################################################################

genfstab -U /mnt > /mnt/etc/fstab

cat << eof | artools-chroot /mnt

# Time Zone
ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime
hwclock --systohc

# Localization
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network Setup
echo "$uName" > /etc/hostname
printf "%s" "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$uName.localdomain\t$uName" > /etc/hosts

# Wifi
pacman -S --noconfirm iwd dhcpcd
systemctl enable iwd dhcpcd

# Root pass
printf "%s" "$rPass\n$rPass\n" | passwd

eof

umount -R /mnt
reboot
