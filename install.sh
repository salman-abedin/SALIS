#!/bin/sh
#
# Artix/Arch linux installer script

read -r DISTRO </etc/os-release

#Update the system clock
case "$DISTRO" in
*Arch*) timedatectl set-ntp true ;;
esac

#===============================================================================
#                             User Info
#===============================================================================

stty -echo
printf "Root Password: "
read -r password_root
stty echo

printf "Machine name: "
read -r name_machine

case "$DISTRO" in
*Arch*)
    printf "Living in Bangladesh? = { (y)es, (n)o }:  "
    read -r locale_bangladesh
    [ "$locale_bangladesh" = y ] &&
        reflector --country Bangladesh --save /etc/pacman.d/mirrorlist
    ;;
esac

#===============================================================================
#                             Partitioning & Mounting
#===============================================================================

lsblk

printf "Device Id? (i.e. sda): "
read -r device
printf 'Boot Partition ID? (i.e. sda"1"): '
read -r boot
printf 'Root Partition ID? (i.e. sda"2"): '
read -r root

if [ -d /sys/firmware/efi ]; then
    : | mkfs.fat -F32 /dev/"$device$boot"
    mkdir -p /mnt/boot/efi
    mount /dev/"$device$boot" /mnt/boot/efi
else
    : | mkfs.ext4 /dev/"$device$boot"
    mkdir /mnt/boot
    mount /dev/"$device$boot" /mnt/boot
fi

: | mkfs.ext4 /dev/"$device$root"
mount /dev/"$device$root" /mnt

#===============================================================================
#                     Base Packages & Firmware Installation
#===============================================================================

PACKAGES="base base-devel linux-zen linux-firmware neovim git"
INIT_SYSTEM="runit elogind-runit"

case "$DISTRO" in
*Arch*) pacstrap /mnt --noconfirm $PACKAGES ;;
*) basestrap /mnt --noconfirm $PACKAGES $INIT_SYSTEM ;;
esac

#===============================================================================
#                             Essential Configurations
#===============================================================================

case "$DISTRO" in
*Arch*) FSTAB_GEN_CMD=genfstab ;;
*) FSTAB_GEN_CMD=fstabgen ;;
esac
$FSTAB_GEN_CMD -U /mnt >/mnt/etc/fstab

case "$DISTRO" in
*Arch*) CHROOT_CMD_PREFIX=arch ;;
*) CHROOT_CMD_PREFIX=artix ;;
esac
cat <<EOF | $CHROOT_CMD_PREFIX-chroot /mnt

#---------------------------------------
# Time Zone
#---------------------------------------
ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime

case $DISTRO in
  *Arch*) : ;;
  *)
    pacman -Syy --noconfirm ntp
    ntpd -qg
    ;;
esac

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
echo $name_machine > /etc/hostname
cat << eof1 | tee /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $name_machine.localdomain     $name_machine
eof1

#---------------------------------------
# Root pass
#---------------------------------------
printf "$password_root\n$password_root\n" | passwd

#---------------------------------------
# Repository Update
#---------------------------------------

case $DISTRO in
  *Arch*) : ;;
  *)
   pacman -S --noconfirm artix-archlinux-support
    cat << eof1 | tee -a /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
eof1
    pacman-key --populate archlinux
    ;;
esac

pacman -Syu

#---------------------------------------
# Wifi tools
#---------------------------------------
case $DISTRO in
  *Arch*)
   pacman -S --noconfirm networkmanager
   systemctl enable NetworkManager
    ;;
  *)
   pacman -S --noconfirm networkmanager-runit
   ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default
    ;;
esac

#---------------------------------------
# Rfkill
#---------------------------------------
case $DISTRO in
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
pacman -S --noconfirm grub os-prober intel-ucode
[ -d /sys/firmware/efi ] && pacman -S --noconfirm efibootmgr
grub-install /dev/sd$device
sed -i \
   -e "s/.*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/" \
   -e 's/.*GRUB_SAVE.*/GRUB_SAVEDEFAULT="true"/' \
   -e "s/.*GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/" \
   /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

EOF

umount -R /mnt
reboot

# ╔══════════════════════════════════════════════════════════════════════
# ║                              Exp
# ╚══════════════════════════════════════════════════════════════════════

# #---------------------------------------
# # Wifi script for post reboot connection
# #---------------------------------------
# cat << eof1 | tee /root/connect
# CARD=\$(ip link | grep -o 'wl.\w*')
# for op in disconnect scan get-networks; do iwctl station "\$CARD" "\$op"; done
# echo "SSID?: "; read -r SSID
# echo "PASS?: "; read -r PASS
# iwctl --passphrase "\$PASS" station "\$CARD" connect "\$SSID"
# iwctl station "\$CARD" show
# eof1
# #---------------------------------------
# # Wifi tools
# #---------------------------------------
# case "$DISTRO" in
#   *Arch*)
#    pacman -S --noconfirm iwd dhcpcd
#    systemctl enable iwd dhcpcd
#     ;;
#   *)
#    pacman -S --noconfirm iwd-runit dhcpcd-runit
#    ln -s /etc/runit/sv/iwd /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default
#     ;;
# esac
