pacman -S gnome gnome-tweaks gnome-browser-connector ufw cups system-config-printer nss-mdns

#enable GDM
sudo systemctl enable --now gdm.service

#enable bluetooth
sudo systemctl enable --now bluetooth.service

#enable CUPS
sudo systemctl enable --now cups.service

#enable multicast DNS / DNS Service Discovery
sudo systemctl enable --now avahi-daemon.service
