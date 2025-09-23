#!/bin/bash

# ==============================================================================
# Hyprland AMD Setup Script for Arch Linux
# ==============================================================================
# This script automates the installation and configuration of AMD GPU drivers
# for use with Hyprland on Arch Linux, following the official Hyprland wiki.
#
# Author: https://github.com/soaresluciano
# ==============================================================================

# --- GPU Detection ---
if lspci | grep -i 'VGA' | grep -iq 'AMD\|ATI'; then
  # Enable multilib repository for 32-bit libraries
  if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\s*\[multilib\]/,/^#\s*Include/ s/^#\s*//' /etc/pacman.conf
  fi

  # Install packages
  PACKAGES_TO_INSTALL=(
    "mesa"                  # OpenGL/Vulkan drivers
    "xf86-video-amdgpu"     # X.org AMD GPU driver (optional, for Xorg)
    "libva-mesa-driver"     # VA-API hardware acceleration
    "vulkan-radeon"         # Vulkan support
    "lib32-mesa"            # 32-bit OpenGL/Vulkan drivers
    "lib32-vulkan-radeon"   # 32-bit Vulkan support
    "egl-wayland"           # EGL support for Wayland
  )

  sudo pacman -S --color always --needed "${PACKAGES_TO_INSTALL[@]}"

  # Add AMD environment variables to hyprland.conf (optional, for VA-API)
  HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"
  if [ -f "$HYPRLAND_CONF" ]; then
    cat >>"$HYPRLAND_CONF" <<'EOF'

# AMD environment variables
env = LIBVA_DRIVER_NAME,mesa
EOF
  fi
fi
