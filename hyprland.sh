#!/bin/bash
set -e

sys_pkgs=(
    flatpak
    fwupd
)

session_pkgs=(
    uwsm
    ly
)

hyper_pkgs=(
    hyprland
    xdg-desktop-portal-hyprland
    hyprpolkitagent
    hyprpaper
    hyprlock
    hypridle
)

core_apps=(
    waybar
    kitty
    wofi
    nemo
    swaync
    grim
)

gtk_pkgs=(
    adw-gtk-theme
    nwg-look
)

qt_pkgs=(
    hyprland-qt-support
    qt6-multimedia-ffmpeg
    kvantum
)

keyring_pkgs=(
    libsecret
    gnome-keyring
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
    blueman
)

filesystem_pkgs=(
    fuse3
    fuse-common
    udiskie
)

printer_pkgs=(
    cups
    cups-pdf
    system-config-printer
)

network_pkgs=(
    network-manager-applet
    gufw
)

packages=(
    "${sys_pkgs[@]}" 
    "${session_pkgs[@]}"
    "${hyper_pkgs[@]}" 
    "${core_apps[@]}" 
    "${basic_apps[@]}" 
    "${gtk_pkgs[@]}" 
    "${qt_pkgs[@]}" 
    "${keyring_pkgs[@]}" 
    "${sound_pkgs[@]}" 
    "${bluetooth_pkgs[@]}" 
    "${filesystem_pkgs[@]}" 
    "${printer_pkgs[@]}"
    "${network_pkgs[@]}"
)

sudo pacman -S --color always --needed "${packages[@]}"

# Enable ly
sudo systemctl enable ly.service
# Disable getty@tty2 to prevent conflicts with ly display manager
systemctl disable getty@tty2.service

systemctl --user enable --now hyprpolkitagent.service
