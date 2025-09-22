#!/bin/bash

sys_pkgs=(
   flatpak
   fwupd
   openssh
   reflector
)

session_pkgs=(
    uwsm
    ly
)

hyper_pkgs=(
    hyprland
    xdg-desktop-portal-hyprland
    hyprpolkitagent
)

hypr_apps=(
    waybar
    kitty
    wofi
    nemo
    hyprpaper
    swaync
)

basic_apps=(
    bat
    chezmoi
    exa
    fzf
)

gtk_pkgs=(
    adw-gtk-theme
    nwg-look
)

qt_pkgs=(
    qt5-wayland
    qt6-wayland
    qt6-multimedia-ffmpeg
    kvantum
)

keyring_pkgs=(
    libsecret
    gnome-keyring
    seahorse
)

sound_pkgs=(
    pipewire
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    wireplumber
    pavucontrol
)

bluetooth_pkgs=(
    bluez
    bluez-utils
    #blueman
)

filesystem_pkgs=(
    fuse3
    fuse-common
    udiskie
)

network_pkgs=(
    network-manager-applet
    uwf
    #guwf
)

packages=(
    "${sys_pkgs[@]}" 
    "${sessio_pkgs[@]}"
    "${hyper_pkgs[@]}" 
    "${hyper_apps[@]}" 
    "${basic_apps[@]}" 
    "${gtk_pkgs[@]}" 
    "${qt_pkgs[@]}" 
    "${keyring_pkgs[@]}" 
    "${sound_pkgs[@]}" 
    "${bluetooth_pkgs[@]}" 
    "${filesystem_pkgs[@]}" 
    "${network_pkgs[@]}"
)

sudo pacman -S --color always --needed "${packages[@]}"

# Enable ly
sudo systemctl enable ly.service
systemctl disable getty@tty2.service
