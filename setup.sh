# https://wiki.archlinux.org/title/Installation_guide

function pause(){
    echo -n "Press any key to continue..."
    read -n 1 -s
}

function new_step(title){
    echo "----------------------------------------"
    echo $title
    echo "----------------------------------------"
    pause
}

# 3.3 - Time
new_step "Setting up time zone and localization"
read -p "Enter your time zone (e.g., Europe/Amsterdam): " timezone
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# 3.4 - Localization
new_step "Generating locales"

read -p "Enter your locale (e.g., en_US.UTF-8): " locale
sed -i "s/#$locale/$locale/" /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/locale.conf

# 3.5 - Network configuration
new_step "Configuring network"
read -p "Enter your hostname (e.g., archlinux): " hostname
echo "$hostname" > /etc/hostname

# EXTRA - Install necessary packages
new_step "Installing necessary packages"
pacman -S --needed --noconfirm \
    grub \
    efibootmgr \
    networkmanager \
    base-devel \
    sudo \
    neovim \
    curl \
    wget \
    iw \
    wpa_supplicant \
    findutils

# 3.5 - Root password
new_step "Setting root password"
echo "Set password for root:"
passwd

# EXTRA - Enable wheel group sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# EXTRA - Add a user
new_step "Creating new user and setting password"
read -p "Enter username: " username
useradd -mG wheel,users $username
echo "Set password for $username:"
passwd $username

# EXTRA - Enable NetworkManager
new_step "Enabling NetworkManager service"
systemctl enable NetworkManager

# 3.8 - Boot loader
new_step "Installing and configuring GRUB bootloader"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# 4 - Reboot
new_step "Finalizing installation and rebooting"
umount -R /mnt
exit
echo "Rebooting..."
pause()
reboot