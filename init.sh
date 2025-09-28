#1.5 Set the console keyboard layout 
loadkeys br-abnt2

#1.6 Verify the boot mode
cat /sys/firmware/efi/fw_platform_size

#1.7 Connect to the internet 
ip link

ping ping.archlinux.org

iwctl

device list
station name scan
station name get-networks
station name connect SSID
exit

ping ping.archlinux.org