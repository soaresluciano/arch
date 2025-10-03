#!/bin/bash

flatpaks=(
  cc.arduino.IDE2
  com.anydesk.Anydesk
  com.heroicgameslauncher.hgl
  com.usebottles.bottles
  com.github.tchx84.Flatseal
  ua.org.brezblock.q4wine
  net.davidotek.pupgui2
  org.keystore_explorer.KeyStoreExplorer
  org.localsend.localsend_app
)

for flatpak in "${flatpaks[@]}"; do
  flatpak install flathub "$flatpak"
done

