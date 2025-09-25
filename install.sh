#!/bin/bash
set -e

# 2.1 Select the mirrors
echo ":: Creating mirrorlist"
reflector --protocol http,https --latest 200 --sort rate --country France,German,Belgium,Netherlands --save /etc/pacman.d/mirrorlist

# 2.2 Install essential packages
echo ":: Installing essential packages"

echo "What is your CPU brand?"
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
echo ":: Creating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "----------------------------------------"
echo ":: Done!"
echo "- You can execute:"
echo "arch-chroot /mnt"
echo "- and then you can proceed with the setup script using:"
echo "curl -Lo setup.sh https://bit.ly/4nlB3h1 && chmod +x setup.sh"