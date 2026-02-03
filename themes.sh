#!/bin/bash
set -e

gtk_pkgs=(
    adw-gtk-theme
    nwg-look
)

qt_pkgs=(
    qt6ct
    qt5ct
)

packages=(
    "${gtk_pkgs[@]}" 
    "${qt_pkgs[@]}" 
)

sudo pacman -S --color always --needed "${packages[@]}"

# Ensure Qt apps use the Qt config tool (set to qt6ct for Qt6)
sudo tee /etc/profile.d/qt-platformtheme.sh > /dev/null <<'EOF'
export QT_QPA_PLATFORMTHEME=qt6ct
EOF

# Set GTK dark theme via gsettings
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'

# Create qt6ct config for dark palette
mkdir -p ~/.config/qt6ct
cat > ~/.config/qt6ct/qt6ct.conf <<'EOF'
[Appearance]
style=Fusion
color_scheme_path=/usr/share/qt6ct/colors/darker.conf
icon_theme=Adwaita
EOF

# Create qt5ct config for dark palette
mkdir -p ~/.config/qt5ct
cat > ~/.config/qt5ct/qt5ct.conf <<'EOF'
[Appearance]
style=Fusion
color_scheme_path=/usr/share/qt5ct/colors/darker.conf
icon_theme=Adwaita
EOF

echo "Done. Log out and back in to apply theme."
