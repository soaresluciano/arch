#!/bin/bash

sudo pacman -S --needed \
    hyprland \
    uwsm \
    xdg-desktop-portal-hyprland \
    hyprpolkitagent \
    qt5-wayland \
    qt6-wayland \
    qt6-multimedia-ffmpeg \
    kvantum \
    adw-gtk-theme \
    nwg-look \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    hyprpaper \
    udiskie \
    waybar \
    ly \
    kitty \
    wofi \
    nemo \
    swaync \
    fuse3 \
    fuse-common \
    bluez \
    bluez-utils \
    libsecret \
    gnome-keyring \
    seahorse \
    network-manager-applet

# Enable ly
sudo systemctl enable ly.service
systemctl disable getty@tty2.service
