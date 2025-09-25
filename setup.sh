#!/bin/bash
set -e

# https://wiki.archlinux.org/title/Installation_guide

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function pause() {
    echo "Press any key to continue..."
    read -n 1 -s
}

function new_step() {
    echo "----------------------------------------"
    echo -e "${YELLOW}$1${NC}"
    echo "----------------------------------------"
    #pause
}

function prompt_with_default() {
    local prompt_message="$1"
    local default_value="$2"

    read -p "$prompt_message (Press enter for default: '$default_value'): " user_input
    if [ -z "$user_input" ]; then
        user_input="$default_value"
        echo "Using default: $user_input"
    fi
    
    echo "$user_input"
}

# 3.3 - Time
new_step "Setting timezone"
zoneinfo=$(prompt_with_default "Enter your timezone" "Europe/Amsterdam")

ln -sf "/usr/share/zoneinfo/$zoneinfo" /etc/localtime
hwclock --systohc

# 3.4 - Localization
new_step "Generating locales"

locale=$(prompt_with_default "Enter your locale" "en_IE.UTF-8")
sed -i "s/#$locale/$locale/" /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/locale.conf

# 3.5 - Network configuration
new_step "Configuring network"
hostname=$(prompt_with_default "Enter your hostname" "archlinux")
echo "$hostname" > /etc/hostname

# EXTRA - Install necessary packages
new_step "Installing necessary packages"

boot_manager_pkgs=(
    grub
    efibootmgr
    os-prober
)

sudo pacman -S --color always --needed "${boot_manager_pkgs[@]}"

# 3.5 - Root password
new_step "Setting root password"
echo "=> Set password for root:"
passwd

# EXTRA - Enable wheel group sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# EXTRA - Add a user
new_step "Creating new user and setting password"
read -p "Enter username: " username
useradd -mG wheel,users $username
echo "=> Set password for $username:"
passwd $username

# EXTRA - Enable NetworkManager
new_step "Enabling NetworkManager service"
systemctl enable NetworkManager

# 3.8 - Boot loader
new_step "Installing and configuring GRUB bootloader"
echo "Make sure your EFI System Partition (ESP) is mounted at /boot or /boot/efi before proceeding."
esp_mounted=$(prompt_with_default "Is your ESP mounted at /boot (or /boot/efi)?" "n")
if [[ "$esp_mounted" == "y" || "$esp_mounted" == "Y" ]]; then
    # Install GRUB to the ESP, create boot entry "GRUB"
    EFI_DIR=$(prompt_with_default "Enter your EFI directory" "/boot")
    grub-install --target=x86_64-efi --efi-directory="$EFI_DIR" --bootloader-id=GRUB

    # Enable os-prober in GRUB configuration so Windows is detected
    if ! grep -q "^GRUB_DISABLE_OS_PROBER=false" /etc/default/grub; then
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    fi

    # Generate GRUB config (includes Windows if detected)
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "Please mount your EFI System Partition and try again."
    exit 1
fi

# 4 - Reboot
new_step "Finalizing installation and rebooting"
#umount -R /mnt
exit
echo "Rebooting..."
pause
reboot
