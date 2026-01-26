#!/bin/bash
# Minimal XFCE for HP Pavilion - Debian 13 (Trixie) - VERIFIED FIX
set -e
trap 'echo "Error on line $LINENO. Exiting."; exit 1' ERR

if [ "$EUID" -ne 0 ]; then
   echo "This script must be run as root."
   exit 1
fi

echo "Starting XFCE installation for HP Pavilion..."

# 0. Configure User
apt update && apt install -y sudo
usermod -aG sudo,netdev m || true
groupadd -r autologin 2>/dev/null || true
usermod -aG autologin m

# 1. Repositories (Adding non-free for HP WiFi)
sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list 2>/dev/null || true
if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
fi

# 2. The Clean Install (Removed policykit-1-gnome entirely)
apt update && apt upgrade -y
apt install -y --no-install-recommends \
    xserver-xorg-core xserver-xorg xinit xserver-xorg-input-libinput \
    lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 thunar xfce4-terminal xfce4-settings \
    xfce4-whiskermenu-plugin xfce4-power-manager xfce4-notifyd \
    network-manager-gnome pulseaudio pavucontrol mousepad \
    thunar-archive-plugin gvfs gvfs-backends dbus-x11 \
    polkitd upower acpi-support acpid

# 3. HP Firmware
set +e
apt install -y --no-install-recommends \
    firmware-linux-nonfree firmware-iwlwifi firmware-realtek \
    firmware-atheros firmware-libertas firmware-brcm80211
set -e

# 4. Settings & Autologin
mkdir -p /etc/lightdm/lightdm.conf.d/
echo -e "[Seat:*]\nautologin-user=m\nautologin-user-timeout=0" > /etc/lightdm/lightdm.conf.d/01-autologin.conf

# 5. Touchpad Tap-to-Click
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/40-libinput.conf <<EOF
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
EndSection
EOF

echo "Done! Rebooting..."
sleep 3
reboot
