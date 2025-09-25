#!/bin/bash
set -e

# 2.1 Select the mirrors
echo -n ":: Creating mirrorlist"
reflector --protocol http,https --latest 200 --sort rate --country France,German,Belgium,Netherlands --save /etc/pacman.d/mirrorlist

# 2.2 Install essential packages
echo -n ":: Installing essential packages"

echo -n "What is your CPU brand?"
echo "  1. AMD | 2. Intel"
echo "Info found:"
lscpu | grep "Model name:"
read -p "Select a number: " choice
case "$choice" in
    1 )
        CPU_ucode=amd-ucode
        ;;
    2 )
        CPU_ucode=intel-ucode
        ;;
    * )
        CPU_ucode=Null
        echo "Invalid choice, proceeding without microcode."
        ;;
esac

mandatory_pkgs=(
    base
    linux
    linux-firmware
)

before_reboot_pkgs=(
    sudo
    networkmanager
    base-devel
    sudo
    curl
    wget
    iw
    wpa_supplicant
    crda
    findutils
    rsync
    man-db
    man-pages
    git
)

packages=("${mandatory_pkgs[@]}" "${before_reboot_pkgs[@]}")
if [[ "$CPU_ucode" != "Null" ]]; then
    packages+=("$CPU_ucode")
fi

pacstrap -K /mnt "${packages[@]}"

# 3.1 Fstab
echo -n ":: Creating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo -n ":: Done!"
echo -n "- You can execute:"
echo -n "arch-chroot /mnt"
echo -n ""
echo -n "- and then you can proceed with the setup script"
