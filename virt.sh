#!/bin/bash

sudo pacman -S \
  qemu-base \
  libvirt \
  edk2-ovmf \
  virt-install \
  virt-viewer \
  dnsmasq \
  --needed
