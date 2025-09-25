#!/bin/bash
set -e

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function new_step() {
    echo "----------------------------------------"
    echo -e "${YELLOW}$1${NC}"
    echo "----------------------------------------"
    #pause
}

# 2.1 Select the mirrors
new_step "Creating mirrorlist"
reflector --protocol http,https --latest 200 --sort rate --country France,German,Belgium,Netherlands --save /etc/pacman.d/mirrorlist

# 2.2 Install essential packages
new_step "Installing essential packages"

echo "What is your CPU brand?"
echo "Info found:" && lscpu | grep "Model name:"
echo "  1. AMD | 2. Intel"
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
new_step "Creating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# 3.2 Download setup script for chroot environment
new_step "Downloading setup script"
curl -Lo /mnt/tmp/setup.sh https://raw.githubusercontent.com/soaresluciano/arch/refs/heads/main/setup.sh && chmod +x /mnt/tmp/setup.sh

echo "----------------------------------------"
echo ":: Done!"
echo "- You can execute:"
echo  -e "${GREEN}arch-chroot /mnt${NC}"
echo "- and then you can run the setup script with:"
echo "./tmp/setup.sh"