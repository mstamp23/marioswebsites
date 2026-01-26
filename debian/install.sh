#!/bin/bash
# Minimal XFCE for HP Pavilion - Debian 13 (Trixie)
set -e
trap 'echo "Error on line $LINENO. Exiting."; exit 1' ERR

if [ "$EUID" -ne 0 ]; then
   echo "This script must be run as root. Use: sudo bash script.sh"
   exit 1
fi

echo "Starting XFCE installation for HP Pavilion..."

# 0. Configure Existing User "m"
echo "[0/7] Updating permissions for user 'm'..."
apt update
apt install -y sudo

usermod -aG sudo,netdev m || echo "User m already in groups."
groupadd -r autologin 2>/dev/null || true
usermod -aG autologin m

# 1. Enable Non-Free Firmware Repositories
echo "[1/7] Configuring repositories..."
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
fi

if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.backup
    sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
fi

# 2. Update and Install Core System + Power Management
echo "[2/7] Installing XFCE Desktop and Power Tools..."
apt update
apt upgrade -y

# REPLACED xfce-polkit with policykit-1-gnome
apt install -y --no-install-recommends \
    xserver-xorg-core xserver-xorg xinit xserver-xorg-input-libinput \
    lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 thunar xfce4-terminal xfce4-settings \
    xfce4-whiskermenu-plugin xfce4-power-manager xfce4-notifyd \
    network-manager-gnome pulseaudio pavucontrol mousepad \
    thunar-archive-plugin gvfs gvfs-backends dbus-x11 \
    polkitd policykit-1-gnome upower acpi-support acpid

# 3. Install HP Pavilion WiFi & Bluetooth Firmware
echo "[3/7] Installing firmware..."
set +e
apt install -y --no-install-recommends \
    firmware-linux-nonfree firmware-iwlwifi firmware-realtek \
    firmware-atheros firmware-libertas firmware-brcm80211 || echo "Warning: Firmware skip."
set -e

# 4. Set Workspaces to 1
echo "[4/7] Setting workspace count..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="workspace_count" type="int" value="1"/>
  </property>
</channel>
EOF

# 5. Enable Login Screen and Autologin
echo "[5/7] Configuring LightDM and Autologin..."
mkdir -p /etc/lightdm/lightdm.conf.d/
cat > /etc/lightdm/lightdm.conf.d/01-autologin.conf <<EOF
[Seat:*]
autologin-user=m
autologin-user-timeout=0
EOF

systemctl enable lightdm

# 6. Enable Tap-to-Click for HP Touchpad
echo "[6/7] Enabling Tap-to-Click..."
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/40-libinput.conf <<EOF
Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
EndSection
EOF

# 7. Final Power Fix: Polkit permissions
echo "[7/7] Applying Polkit permissions..."
mkdir -p /etc/polkit-1/rules.d/
cat > /etc/polkit-1/rules.d/50-power.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
         action.id == "org.freedesktop.login1.reboot" ||
         action.id == "org.freedesktop.login1.reboot-multiple-sessions") &&
        subject.user == "m") {
        return polkit.Result.YES;
    }
});
EOF

# Finalize
echo "================================"
echo "Installation complete!"
echo "Autologin and Power fixed."
echo "================================"
echo "Rebooting in 5 seconds..."
sleep 5
reboot
