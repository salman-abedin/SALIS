#!/usr/bin/env bash

#Update the system clock
timedatectl set-ntp true

##############################################################################################################
#                                                 User Info
##############################################################################################################

while :; do
   read -pr "User Name?: " uName
   [ "$uName" ] && break
   echo 'This script doesnt work for bastards'
done

while :; do
   read -prs "Root Password?: " rPass
   [ "$rPass" ] && break
   echo 'This script doesnt work for retards'
done

read -pr "Server Address? (Press 'Enter' If you live in Bangladesh): " server

##############################################################################################################
#                                                 Partitioning & Mounting
##############################################################################################################

lsblk

while :; do
   read -pr "Device Letter? (Be careful!): " device
   [ "$device" ] && break
   echo 'This script doesnt work for retards'
done

while :; do
   read -pr "Root Partition Digit? (Be careful!): " root
   [ "$root" ] && break
   echo 'This script doesnt work for retards'
done

root=/dev/sd$device$root

yes | mkfs.ext4 "$root"

mount "$root" /mnt

##############################################################################################################
#                                                 Base Packges & Firmware Installation
##############################################################################################################

[ "$server" ] || server='http://mirror.xeonbd.com/archlinux/$repo/os/$arch'
echo "Server = $server" > /etc/pacman.d/mirrorlist

pacstrap /mnt --noconfirm base linux-firmwar

##############################################################################################################
#                                                 Configuration
##############################################################################################################

genfstab -U /mnt > /mnt/etc/fstab

cat <<- EOF1 | arch-chroot /mnt

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
pacman -S --noconfirm iwd
systemctl enable iwd systemd-resolved
printf "[General]\nEnableNetworkConfiguration=true\n" > /etc/iwd/main.conf

# Root pass
printf "%s" "$rPass\n$rPass\n" | passwd

EOF1

umount -R /mnt
reboot
