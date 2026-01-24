#!/bin/bash
# Greybird-Dark Setup for XFCE - Debian 13
# Focus: Reliable, Native, Eye-Friendly, Professional

set -e

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

# Get the actual user who called sudo
REAL_USER=${SUDO_USER:-$USER}

echo "Step 1: Removing the old problematic custom theme..."
rm -rf /usr/share/themes/Xfce-Dark-Pro

echo "Step 2: Installing Greybird and Core Dependencies..."
apt update
apt install -y \
    greybird-gtk-theme \
    papirus-icon-theme \
    fonts-dejavu \
    xfconf

echo "Step 3: Setting Greybird-dark as the Global Default for new users..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Greybird-dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="FontName" type="string" value="DejaVu Sans 10"/>
  </property>
</channel>
EOF

echo "Step 4: Applying to current user: $REAL_USER"
# Apply the UI theme
sudo -u "$REAL_USER" xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird-dark" || true
# Apply the Window Borders
sudo -u "$REAL_USER" xfconf-query -c xfwm4 -p /general/theme -s "Greybird-dark" || true
# Apply the Icons
sudo -u "$REAL_USER" xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" || true

echo "-------------------------------------------------------"
echo "Done! Greybird-dark is now active."
echo "Your menus should now be perfectly readable."
echo "-------------------------------------------------------"
