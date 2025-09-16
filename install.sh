# 2.1 Select the mirrors
echo -n ":: Creating mirrorlist"
reflector --latest 200 --sort rate --country France,German,Belgium,Netherlands --save /etc/pacman.d/mirrorlist

# 2.2 Install essential packages
echo -n ":: Installing essesitial packages"
pacstrap -K /mnt base linux linux-firmware
pacstrap -K /mnt \
    sudo \
    networkmanager \
    base-devel \
    sudo \
    vim \
    curl \
    wget \
    iw \
    wpa_supplicant \
    crda \
    findutils \
    rsync \
    man-db \
    man-pages

read -p "The CPU brand is: (amd/intel)" CPU
pacstrap -K /mnt "$CPU-ucode"

# 3.1 Fstab
echo -n ":: Creating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo -n ":: Done!"
echo -n "- You can execute:"
echo -n "arch-chroot /mnt"
echo -n ""
echo -n "- and then:"
echo -n "wget https://raw.githubusercontent.com/soaresluciano/arch/refs/heads/main/setup.sh"
