#!/bin/sh
#
# Artix/Arch linux installer script

setfont -d

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

printf "\nMachine name: "
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

printf "\nDevice Id? (i.e. sda): "
read -r device

printf 'Boot Partition ID? (i.e. sda"1"): '
read -r boot
printf 'Root Partition Path? (i.e. vg1/root): '
read -r path_root
# printf 'Home Partition Path? (i.e. vg1/home): '
# read -r path_home
# printf 'Data Partition Path? (i.e. vg1/data): '
# read -r path_data

# cryptsetup luksFormat /dev/"$device$root"
# cryptsetup open /dev/"$device$root" cryptlvm
# pvcreate /dev/mapper/cryptlvm
# vgcreate vg1 /dev/mapper/cryptlvm
# lvcreate -L 50G vg1 -n root
# lvcreate -L 10G vg1 -n home
# lvcreate -l 100%FREE vg1 -n data

: | mkfs.ext4 /dev/"$path_root"
mount /dev/"$path_root" /mnt

: | mkfs.fat -F32 /dev/"$device$boot"
mount --mkdir /dev/"$device$boot" /mnt/boot/efi

# : | mkfs.ext4 /dev/"$path_home"
# mount --mkdir /dev/"$path_home" /mnt/home
#
# : | mkfs.ext4 /dev/"$path_data"
# mount --mkdir /dev/"$path_data" /mnt/data

# Enable parallel downloads
sed -i "s/#Parallel/Parallel/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

#===============================================================================
#                     Base Packages & Firmware Installation
#===============================================================================

PACKAGES="base base-devel linux-zen linux-firmware neovim npm git lvm2 openssh zsh starship zoxide go wireguard-tools"
INIT_SYSTEM="runit elogind-runit"

case "$DISTRO" in
*Arch*) pacstrap /mnt --noconfirm $PACKAGES ;;
*) basestrap /mnt --noconfirm "$PACKAGES $INIT_SYSTEM" ;;
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

    cat << eof1 | tee -a /etc/pacman.conf
[universe]
Server = https://universe.artixlinux.org/\$arch
Server = https://mirror1.artixlinux.org/universe/\$arch
Server = https://mirror.pascalpuffke.de/artix-universe/\$arch
Server = https://mirrors.qontinuum.space/artixlinux-universe/\$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/\$arch
Server = https://ftp.crifo.org/artix-universe/\$arch
Server = https://artix.sakamoto.pl/universe/\$arch
eof1

    pacman -Syy --noconfirm artix-archlinux-support
    pacman-key --populate archlinux

    cat << eof1 | tee -a /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch
[community]
Include = /etc/pacman.d/mirrorlist-arch
[multilib]
Include = /etc/pacman.d/mirrorlist-arch
eof1

    ;;
esac

pacman -Syu

#---------------------------------------
# Time Zone
#---------------------------------------
ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime
case $DISTRO in
  *Arch*)
    pacman -S --noconfirm chrony
    systemctl enable chronyd
    ;;
  *)
    pacman -S --noconfirm ntp
    ntpd -qg
    ;;
esac
hwclock --systohc

#---------------------------------------
# Wifi tools
#---------------------------------------
case $DISTRO in
*Arch*)
    # pacman -S --noconfirm networkmanager
    # systemctl enable NetworkManager
    pacman -S --noconfirm iwd dhcpcd
    systemctl enable iwd dhcpcd
    ;;
*)
    pacman -S --noconfirm iwd-runit dhcpcd-runit
    ln -s /etc/runit/sv/iwd /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default
    ;;
esac

#---------------------------------------
# Firewall
#---------------------------------------
case $DISTRO in
*Arch*)
    pacman -S --noconfirm ufw
    systemctl enable ufw
    ;;
*)
    pacman -S --noconfirm ufw-runit
    ln -s /etc/runit/sv/ufw /etc/runit/runsvdir/default
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

# #---------------------------------------
# # Encryption
# #---------------------------------------
# sed -i 's/^HOOKS.*block/& lvm2 encrypt/' /etc/mkinitcpio.conf
# mkinitcpio -p linux-zen

#---------------------------------------
# Bootloader
#---------------------------------------
# pacman -S --noconfirm grub os-prober intel-ucode
pacman -S --noconfirm grub
[ -d /sys/firmware/efi ] && pacman -S --noconfirm efibootmgr
# sed -i 's/^#GRUB_ENABLE_CRYPT/GRUB_ENABLE_CRYPT/' /etc/default/grub
grub-install --efi-directory=/boot/efi --target=x86_64-efi --bootloader-id=GRUB /dev/$device
# cryptdevice=UUID=beb1a263-78f3-44e2-ac4c-ecabfb8ae2ae:cryptlvm root=/dev/vg1/root
sed -i \
   -e "s/.*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/" \
   -e 's/.*GRUB_SAVE.*/GRUB_SAVEDEFAULT="true"/' \
   -e "s/.*GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/" \
   /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# umount -R /mnt
# reboot

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
# case $DISTRO in
# *Arch*)
#     pacman -S --noconfirm networkmanager
#     systemctl enable NetworkManager
#     ;;
# *)
#     pacman -S --noconfirm networkmanager-runit
#     ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default
#     ;;
# esac
