# 2.1 Select the mirrors
reflector --latest 200 --sort rate --country France,German,Belgium,Netherlands --save /etc/pacman.d/mirrorlist

# 2.2 Install essential packages
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
genfstab -U /mnt >> /mnt/etc/fstab
