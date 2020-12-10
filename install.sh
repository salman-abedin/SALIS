#!/bin/sh
#
# Artix/Arch linux installer script

#Update the system clock
timedatectl set-ntp true

#===============================================================================
#                             User Info
#===============================================================================

printf "Distro = { (a)rch, (A)rtix }:  "
read -r distro

printf "User Name: "
read -r name_user

printf "Root Password: "
read -r password_root

printf "Machine name: "
read -r name_machine

if [ "$distro" = a ]; then
   printf "Living in Bangladesh? = { (y)es, (n)o }:  "
   read -r locale_bangladesh
   [ "$locale_bangladesh" = y ] &&
      reflector --country Bangladesh --save /etc/pacman.d/mirrorlist
fi

#===============================================================================
#                             Partitioning & Mounting
#===============================================================================

lsblk

printf "Device Letter? (i.e. sd<LETTER>): "
read -r device

printf "Boot partition digit? (i.e. sda<DIGIT>): "
read -r boot
printf "Root partition digit? (i.e. sda<DIGIT>): "
read -r root
printf "Internal partition digit? (i.e. sda<DIGIT>): "
read -r internal

: | mkfs.ext4 /dev/sd"$device$boot"
: | mkfs.ext4 /dev/sd"$device$root"

mkdir /mnt/boot && mount /dev/sd"$device$boot" /mnt/boot
mount /dev/sd"$device$root" /mnt
mkdir -p /mnt/mnt/internal && mount /dev/sd"$device$internal" /mnt/mnt/internal

#===============================================================================
#                     Base Packages & Firmware Installation
#===============================================================================

PACKAGES="base base-devel linux-zen linux-firmware neovim"
INIT_SYSTEM="runit elogind-runit"

if [ "$distro" = A ]; then
   basestrap /mnt --noconfirm $PACKAGES $INIT_SYSTEM
else
   pacstrap /mnt --noconfirm $PACKAGES
fi

#===============================================================================
#                             Essential Configurations
#===============================================================================

if [ "$distro" = A ]; then
   fstabgen -U /mnt > /mnt/etc/fstab
else
   genfstab -U /mnt > /mnt/etc/fstab
fi

if [ "$distro" = A ]; then
   CHROOT=artool
else
   CHROOT=arch
fi

cat << eof | $CHROOT-chroot /mnt

#---------------------------------------
# Time Zone
#---------------------------------------
ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime
hwclock --systohc

#---------------------------------------
# Localization
#---------------------------------------
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

#---------------------------------------
# Network Setup
#---------------------------------------
echo "$name_machine" > /etc/hostname
cat << eof1 | tee /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $name_machine.localdomain     $name_machine
0.0.0.0   get.code-industry.net
eof1

#---------------------------------------
# Root pass
#---------------------------------------
printf "$password_root\n$password_root\n" | passwd

#---------------------------------------
# Wifi tools
#---------------------------------------
if [ "$distro" = A ]; then
   pacman -S --noconfirm iwd-runit dhcpcd-runit
   ln -s /etc/runit/sv/iwd /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default
else
   pacman -S --noconfirm iwd dhcpcd
   systemctl enable iwd dhcpcd
fi

if [ "$distro" = A ]; then
   # rfkill
   mkdir /etc/runit/sv/rfkill
cat << eof1 | tee /etc/runit/sv/rfkill/run
#!/bin/sh
exec /usr/bin/rfkill unblock all 2>&1
eof1
   chmod +x /etc/runit/sv/rfkill/run
   ln -s /etc/runit/sv/rfkill /etc/runit/runsvdir/default
fi

#---------------------------------------
# Bootloader
#---------------------------------------
pacman -S --noconfirm grub os-prober intel-ucode
grub-install /dev/sd$device
sed -i \
   -e "s/.*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/" \
   -e 's/.*GRUB_SAVE.*/GRUB_SAVEDEFAULT="true"/' \
   -e "s/.*GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/" \
   /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

#---------------------------------------
# Wifi script for post reboot connection
#---------------------------------------
cat << eof1 | tee /root/connect
CARD=$(ip link | grep -o 'wl.\w*')
for op in disconnect scan get-networks; do iwctl station "$CARD" "$op"; done
echo "SSID?: "; read -r SSID
echo "PASS?: "; read -r PASS
iwctl --passphrase "$PASS" station "$CARD" connect "$SSID"
iwctl station "$CARD" show
eof1

eof

umount -R /mnt
reboot
