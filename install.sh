#!/bin/bash
# Minimal XFCE for HP Pavilion - Debian 13

# 1. Update and Install
apt update && apt upgrade -y
apt install -y --no-install-recommends \
    xserver-xorg-core xserver-xorg xinit \
    lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 thunar xfce4-terminal xfce4-settings \
    xfce4-whiskermenu-plugin xfce4-power-manager xfce4-notifyd \
    network-manager-gnome pulseaudio pavucontrol mousepad \
    thunar-archive-plugin

# 2. Set Workspaces to 1 (System-wide default)
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
echo '<?xml version="1.0" encoding="UTF-8"?><channel name="xfwm4" version="1.0"><property name="general" type="empty"><property name="workspace_count" type="int" value="1"/></property></channel>' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

# 3. Enable Login Screen and Finish
systemctl enable lightdm
echo "Done! Unplug USB and rebooting in 5 seconds..."
sleep 5
reboot
