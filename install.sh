#!/bin/sh

#Update the system clock
timedatectl set-ntp true

################################################################################
#                             User Info
################################################################################

printf "%s" "User Name: "
read -r uName

printf "%s" "Root Password: "
read -r rPass

################################################################################
#                             Partioning & Mounting
################################################################################

lsblk

printf "%s" "Device Letter? (Be careful!): "
read -r device

printf "%s" "Root Partition Digit? (Be careful!): "
read -r root

root=/dev/sd$device$root
yes | mkfs.ext4 "$root"
mount "$root" /mnt

################################################################################
#                             Base Packages & Firmware Installation
################################################################################

basestrap /mnt --noconfirm base base-devel linux linux-firmware runit elogind-runit

################################################################################
#                             Configuration
################################################################################

genfstab -U /mnt > /mnt/etc/fstab

cat << EOF | artools-chroot /mnt

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
pacman -S --noconfirm iwd iwd-runit dhcpcd connman
ln -s /etc/runit/sv/iwd /etc/runit/sv/dhcpcd /etc/runit/sv/connman /etc/runit/runsvdir/default

# Root pass
printf "%s" "$rPass\n$rPass\n" | passwd

EOF

# umount -R /mnt
# reboot
