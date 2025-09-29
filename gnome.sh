pkgs=(
  pipewire
  pipewire-alsa
  pipewire-pulse
  pipewire-jack
  wireplumber
  gnome
  gnome-tweaks
  gnome-browser-connector
  ufw
  flatpak
  fwupd
  fuse3
  fuse-common
  cups
  cups-pdf
  system-config-printer
  nss-mdns
)

sudo pacman -S --color always --needed "${pkgs[@]}"

read -p "Configure the services? y/N" awnser
if [ "$user_input" == "y" ]; then
  echo "SETTING UP SERVICES:"
else
  exit 0
fi

#enable GDM
sudo systemctl enable --now gdm.service

#enable bluetooth
sudo systemctl enable --now bluetooth.service

#enable CUPS
sudo systemctl enable --now cups.service

#enable multicast DNS / DNS Service Discovery
sudo systemctl enable --now avahi-daemon.service
