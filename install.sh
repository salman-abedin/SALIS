#!/bin/sh
#
# Artix/Arch linux installer script

#Update the system clock
timedatectl set-ntp true

read -r DISTRO < /etc/os-release

#===============================================================================
#                             User Info
#===============================================================================

printf "Root Password: "
read -r password_root

printf "Machine name: "
read -r name_machine

case "$DISTRO" in
  *Arch*)
    printf "Living in Bangladesh? = { (y)es, (n)o }:  "
    read -r locale_bangladesh
    [ "$locale_bangladesh" = y ] \
      && reflector --country Bangladesh --save /etc/pacman.d/mirrorlist
    ;;
esac

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

if [ -d /sys/firmware/efi ]; then
  # : | mkfs.fat -F32 /dev/sd"$device$boot"
  mkdir -p /mnt/boot/efi
  mount /dev/sd"$device$boot" /mnt/boot/efi
else
  # : | mkfs.ext4 /dev/sd"$device$boot"
  mkdir /mnt/boot
  mount /dev/sd"$device$boot" /mnt/boot
fi

: | mkfs.ext4 /dev/sd"$device$root"

mount /dev/sd"$device$root" /mnt

#===============================================================================
#                     Base Packages & Firmware Installation
#===============================================================================

PACKAGES="base base-devel linux linux-firmware neovim git"
INIT_SYSTEM="runit elogind-runit"

case "$DISTRO" in
  *Arch*) pacstrap /mnt --noconfirm --needed $PACKAGES ;;
  *) basestrap /mnt --noconfirm --needed $PACKAGES $INIT_SYSTEM ;;
esac

#===============================================================================
#                             Essential Configurations
#===============================================================================

case "$DISTRO" in
  *Arch*) genfstab -U /mnt > /mnt/etc/fstab ;;
  *) fstabgen -U /mnt > /mnt/etc/fstab ;;
esac

case "$DISTRO" in
  *Arch*) CHROOT=arch ;;
  *) CHROOT=artix ;;
esac

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
# Fstab
#---------------------------------------
case "$DISTRO" in
  *Arch*) pacman -S --noconfirm --needed arch-install-scripts ;;
  *) pacman -S --noconfirm --needed artools-base ;;
esac

#---------------------------------------
# Wifi tools
#---------------------------------------
case "$DISTRO" in
  *Arch*)
   pacman -S --noconfirm --needed iwd dhcpcd
   systemctl enable iwd dhcpcd
    ;;
  *)
   pacman -S --noconfirm --needed iwd-runit dhcpcd-runit
   ln -s /etc/runit/sv/iwd /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default
    ;;
esac


#---------------------------------------
# Rfkill
#---------------------------------------
case "$DISTRO" in
  *Arch*)
    systemctl enable rfkill-unblock@all
    ;;
  *)
   mkdir /etc/runit/sv/rfkill
cat << eof1 | tee /etc/runit/sv/rfkill/run
#!/bin/sh
exec /usr/bin/rfkill unblock all 2>&1
eof1
   chmod +x /etc/runit/sv/rfkill/run
   ln -s /etc/runit/sv/rfkill /etc/runit/runsvdir/default
    ;;
esac

#---------------------------------------
# Bootloader
#---------------------------------------
pacman -S --noconfirm --needed grub os-prober intel-ucode
[ -d /sys/firmware/efi ] && pacman -S --noconfirm --needed efibootmgr
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
