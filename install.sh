#!/bin/bash

# ============================================================================
# DEBIAN 13 (TRIXIE) - COMPLETE AUTOMATED INSTALLER (v2.0)
# Hardware: Optimized for i9-13900F / NVIDIA GTX 1650 / 64GB RAM / 980 PRO SSD
# ============================================================================

set -e
trap 'echo "❌ Error on line $LINENO. Check /var/log/debian-install.log"; exit 1' ERR

# ============================================================================
# 1. LOGGING & ROOT CHECK
# ============================================================================
mkdir -p /var/log /home/m/launchers /home/m/My-Drive
exec > >(tee -a /var/log/debian-install.log)
exec 2>&1
echo "🚀 Starting Debian 13 Complete Installation - $(date)"

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root"
    exit 1
fi

# ============================================================================
# 2. USER SETUP
# ============================================================================
echo "👤 Setting up user 'm'..."
if ! id -u m &>/dev/null; then
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd
fi

usermod -aG sudo,vboxsf m 2>/dev/null || usermod -aG sudo m

mkdir -p /etc/sudoers.d
cat <<'EOF' > /etc/sudoers.d/m
m ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get
m ALL=(ALL) ALL
Defaults:m timestamp_timeout=30
EOF
chmod 0440 /etc/sudoers.d/m

# ============================================================================
# 3. SOURCES & INITIAL UPDATE
# ============================================================================
echo "📦 Configuring Debian 13 Trixie repositories..."
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

# Use --allow-releaseinfo-change because Trixie is in constant development
apt update --allow-releaseinfo-change
apt upgrade -y

# ============================================================================
# 4. ESSENTIAL TOOLS (FIXED)
# ============================================================================
echo "🔧 Installing essential tools..."
# Split install to avoid 'software-properties-common' blocking other tools
apt install -y sudo wget ca-certificates unzip curl gnupg2 dirmngr lsb-release apt-transport-https

# Debian 13 occasionally handles this package differently; we continue if it fails
apt install -y software-properties-common || echo "⚠️  software-properties-common not found, proceeding..."

apt install -y unattended-upgrades rclone build-essential git speedtest-cli \
    htop gparted ntfs-3g python3-venv python3-pip geany linux-headers-amd64

# ============================================================================
# 5. HARDWARE OPTIMIZATIONS
# ============================================================================
echo "⚡ Applying hardware optimizations..."

# Intel CPU optimization (i9-13900F)
apt install -y intel-microcode thermald cpufrequtils
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils

# NVIDIA GPU drivers (GTX 1650)
if lspci | grep -qi nvidia; then
    echo "🎮 Installing NVIDIA drivers for Trixie..."
    apt install -y nvidia-driver firmware-misc-nonfree nvidia-settings
    
    if ! systemd-detect-virt | grep -q 'oracle\|vmware\|qemu'; then
        mkdir -p /etc/X11/xorg.conf.d/
        cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "ForceFullCompositionPipeline" "on"
EndSection
EOF
    fi
fi

# RAM optimization (64GB) - zRAM
apt install -y zram-tools
echo -e "ALGO=zstd\nPERCENT=25" > /etc/default/zram-tools

# SSD optimization (Samsung 980 PRO)
apt install -y smartmontools
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo 'ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"' > /etc/udev/rules.d/60-scheduler.rules

# ============================================================================
# 6. XFCE DESKTOP ENVIRONMENT
# ============================================================================
echo "🖥️  Installing XFCE..."
apt install -y xfce4 xfce4-terminal lightdm lightdm-gtk-greeter \
    xfce4-power-manager network-manager-gnome pavucontrol thunar \
    xfce4-screenshooter mousepad

# ============================================================================
# 7. LOCALES & KEYBOARD
# ============================================================================
echo "🌍 Setting up locales and keyboard (EN/GR)..."
apt install -y locales
echo -e "en_US.UTF-8 UTF-8\nel_GR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us,gr"
XKBOPTIONS="grp:alt_shift_toggle"
EOF

echo -e "LANG=en_US.UTF-8\nLC_ALL=en_US.UTF-8\nLANGUAGE=en_US:en" > /etc/environment

# ============================================================================
# 8. WINDOWS 10 DARK THEME
# ============================================================================
echo "🎨 Installing Windows 10 Dark theme..."
apt install -y fonts-inter gtk2-engines-murrine gtk2-engines-pixbuf
cd /tmp
wget -O windows10-dark.zip https://github.com/B00merang-Project/Windows-10-Dark/archive/master.zip
unzip -o windows10-dark.zip
mkdir -p /usr/share/themes
mv Windows-10-Dark-master /usr/share/themes/Windows-10-Dark
rm windows10-dark.zip

# Applying theme settings to user 'm'
sudo -u m mkdir -p /home/m/.config/xfce4/xfconf/xfce-perchannel-xml
sudo -u m cat <<EOF > /home/m/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Windows-10-Dark"/>
    <property name="IconThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
  </property>
</channel>
EOF

# ============================================================================
# 9. APPLICATIONS INSTALLATION
# ============================================================================
echo "📱 Installing applications..."
apt install -y firefox-esr vlc qbittorrent yt-dlp ffmpeg flameshot menulibre

# Google Chrome
wget -P /tmp https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -y /tmp/google-chrome-stable_current_amd64.deb || apt --fix-broken install -y

# Viber
wget -P /tmp https://download.cdn.viber.com/desktop/Linux/viber.deb
apt install -y /tmp/viber.deb || apt --fix-broken install -y

# ProtonVPN
wget -q -O - https://repo.protonvpn.com/debian/deb.gpg | gpg --dearmor > /usr/share/keyrings/proton.gpg
echo "deb [signed-by=/usr/share/keyrings/proton.gpg] https://repo.protonvpn.com/debian stable main" > /etc/apt/sources.list.d/protonvpn.list
apt update && apt install -y protonvpn-stable-release protonvpn-cli protonvpn-app || echo "VPN install failed, skip."

# Security: Firewall, Fail2Ban, ClamAV
apt install -y ufw fail2ban clamav clamav-daemon clamtk
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# ============================================================================
# 10. SYSTEM SERVICES (RCLONE & MAINTENANCE)
# ============================================================================
echo "☁️  Setting up rclone daily backup & maintenance..."

# Service for Rclone
cat <<EOF > /etc/systemd/system/rclone-sync.service
[Unit]
Description=Daily Rclone Sync for user m
After=network-online.target

[Service]
Type=oneshot
User=m
ExecStart=/usr/bin/rclone sync /home/m/My-Drive gdrive:My-Drive --exclude "venv/**" --exclude ".git/**" --exclude "python-env/**"
Nice=19
EOF

# Timer for Rclone
cat <<EOF > /etc/systemd/system/rclone-sync.timer
[Unit]
Description=Run Rclone Sync every day at 03:00 AM
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF

systemctl enable rclone-sync.timer

# ============================================================================
# 11. GRUB & FINAL CLEANUP
# ============================================================================
echo "🚀 Optimizing GRUB..."
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 mitigations=off"/' /etc/default/grub
update-grub

echo "🧼 Cleaning up..."
chown -R m:m /home/m/
apt autoremove -y
apt clean

echo "✅ DONE! Rebooting in 10 seconds..."
sleep 10
reboot
