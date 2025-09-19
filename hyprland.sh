#!/bin/bash

core_pkgs=(
    hyprland
    uwsm
    ly
    xdg-desktop-portal-hyprland
    hyprpolkitagent
    swaync
)

apps_pkgs=(
    waybar
    kitty
    wofi
    nemo
    hyprpaper
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
)

packages=(
    "${core_pkgs[@]}" 
    "${apps_pkgs[@]}" 
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
