#!/bin/bash
# ============================================================================
# DEBIAN 13 XFCE COMPLETE INSTALLATION SCRIPT
# Includes Clevis (dormant) and all requested applications
# ============================================================================
set -e
exec > >(tee /var/log/debian-xfce-install.log) 2>&1
echo "🚀 Starting Debian 13 XFCE Installation: $(date)"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Run as root: sudo bash $0"
    exit 1
fi

# 2. USER CONFIGURATION
echo "👤 Configuring user 'm'..."
if ! id -u m &>/dev/null; then
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd
    chage -d 0 m
fi
usermod -aG sudo,vboxsf m 2>/dev/null || usermod -aG sudo m

cat > /etc/sudoers.d/m << 'EOF'
m ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/aptitude
m ALL=(ALL) ALL
Defaults:m timestamp_timeout=30
EOF
chmod 0440 /etc/sudoers.d/m

# 3. SYSTEM BASE
echo "📦 Configuring repositories..."
cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt update && apt full-upgrade -y

# 4. MINIMAL XFCE + GREEK LOCALE
echo "🖥️ Installing minimal XFCE with Greek support..."
apt install -y --no-install-recommends \
    xorg xfce4 xfce4-goodies lightdm lightdm-gtk-greeter \
    network-manager-gnome xfce4-power-manager thunar thunar-archive-plugin \
    locales tzdata keyboard-configuration xfce4-terminal

# Configure Greek
sed -i '/el_GR.UTF-8/s/^# //g' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
cat > /etc/default/keyboard << 'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us,gr"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
EOF
dpkg-reconfigure -f noninteractive keyboard-configuration
echo "Europe/Athens" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# 5. ESSENTIAL SYSTEM TOOLS
echo "🔧 Installing essential tools..."
apt install -y \
    wget curl gnupg ca-certificates git build-essential \
    htop neofetch gparted ntfs-3g python3-venv python3-pip \
    geany linux-headers-amd64 firmware-linux firmware-linux-nonfree \
    intel-microcode thermald apt-transport-https software-properties-common \
    rclone speedtest-cli udisks2

# 6. HARDWARE OPTIMIZATIONS
echo "⚡ Applying hardware optimizations..."

# NVIDIA drivers
if lspci | grep -qi "NVIDIA"; then
    echo "🎮 Installing NVIDIA drivers..."
    apt install -y nvidia-driver nvidia-settings nvidia-vulkan-common
fi

# RAM optimizations
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -ge 8 ]; then
    echo "💾 Configuring zram for ${TOTAL_MEM}GB RAM..."
    apt install -y zram-tools
    echo "ALGO=zstd" > /etc/default/zram-tools
    echo "PERCENT=25" >> /etc/default/zram-tools
    echo "vm.swappiness=10" >> /etc/sysctl.d/99-optimize.conf
    systemctl enable zram-tools --now
fi

# HDD optimizations
cat > /etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
EOF
udevadm control --reload-rules

# 7. USB UNLOCK (CLEVIS) - INSTALLED BUT DORMANT
echo "🔐 Installing Clevis (USB unlock - dormant)..."
apt install -y clevis clevis-luks clevis-initramfs
echo "ℹ️ Clevis installed. Configure later with: sudo setup-usb-unlock"

# Create setup script for later use
cat > /usr/local/bin/setup-usb-unlock << 'EOF'
#!/bin/bash
echo "Clevis USB unlock configuration"
echo "Run this when you want to setup USB disk unlocking"
echo "See: man clevis or visit: https://github.com/latchset/clevis"
EOF
chmod +x /usr/local/bin/setup-usb-unlock

# 8. THEME & VISUAL CUSTOMIZATION
echo "🎨 Installing Windows 10 Dark theme..."
apt install -y unzip
wget -q https://github.com/B00merang-Project/Windows-10-Dark/archive/master.zip -O /tmp/win10-dark.zip
unzip -q /tmp/win10-dark.zip -d /tmp/
mkdir -p /usr/share/themes
mv /tmp/Windows-10-Dark-master /usr/share/themes/Windows-10-Dark 2>/dev/null || true
rm -f /tmp/win10-dark.zip

# Create launchers folder
sudo -u m mkdir -p /home/m/launchers /home/m/My-Drive

# Speedtest launcher
cat > /home/m/launchers/speedtest.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Speedtest
Comment=Internet Speed Test
Exec=xfce4-terminal -e "speedtest-cli"
Icon=network-transmit-receive
Terminal=false
Categories=Network;
EOF
chmod +x /home/m/launchers/speedtest.desktop

# 9. APPLICATION INSTALLATION
echo "📱 Installing applications..."

# Web Browsers
echo "🌐 Installing browsers..."
apt install -y firefox-esr
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
apt install -y /tmp/chrome.deb 2>/dev/null || apt --fix-broken install -y
rm -f /tmp/chrome.deb

# Multimedia
echo "🎵 Installing multimedia tools..."
apt install -y vlc qbittorrent yt-dlp ffmpeg

# Utilities
echo "🛠️ Installing utilities..."
apt install -y flameshot menulibre keepassxc gimp inkscape libreoffice filezilla

# VPN
echo "🔒 Installing ProtonVPN..."
wget -q https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.3-2_all.deb -O /tmp/protonvpn.deb
apt install -y /tmp/protonvpn.deb
apt update
apt install -y protonvpn-cli
rm -f /tmp/protonvpn.deb

# Viber
echo "💬 Installing Viber..."
wget -q https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb -O /tmp/viber.deb
apt install -y /tmp/viber.deb 2>/dev/null || apt --fix-broken install -y
rm -f /tmp/viber.deb

# 10. SECURITY & MAINTENANCE
echo "🛡️ Configuring security..."

# Firewall
apt install -y ufw
ufw --force enable
ufw default deny incoming
ufw default allow outgoing

# Antivirus
apt install -y clamav clamav-daemon clamtk
freshclam

# Disable unnecessary services
systemctl disable bluetooth.service 2>/dev/null || true
systemctl disable cups.service 2>/dev/null || true
systemctl disable cups-browsed.service 2>/dev/null || true

# Unattended security updates
apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

# 11. SCHEDULED MAINTENANCE
echo "⏰ Setting up scheduled tasks..."

# Rclone sync setup (dormant - configure later)
cat > /etc/systemd/system/rclone-sync.service << 'EOF'
[Unit]
Description=Rclone Sync Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=m
ExecStart=/bin/echo "Configure rclone first with: rclone config"
Environment=PATH=/usr/bin:/bin:/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/rclone-sync.timer << 'EOF'
[Unit]
Description=Daily Rclone Sync Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Monthly maintenance script
cat > /usr/local/bin/monthly-maintenance << 'EOF'
#!/bin/bash
# Monthly system maintenance
logger "Starting monthly maintenance"
apt update -qq
apt full-upgrade -y -qq
apt autoremove --purge -y -qq
apt autoclean -qq
updatedb
journalctl --vacuum-time=30d
logger "Monthly maintenance completed"
EOF
chmod +x /usr/local/bin/monthly-maintenance

cat > /etc/systemd/system/monthly-maintenance.timer << 'EOF'
[Unit]
Description=Monthly System Maintenance Timer

[Timer]
OnCalendar=*-*-01 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable monthly-maintenance.timer

# 12. PYTHON ENVIRONMENT
echo "🐍 Setting up Python environment..."
sudo -u m mkdir -p /home/m/My-Drive/python_projects
sudo -u m python3 -m venv /home/m/My-Drive/python_env

# Geany configuration for Python
sudo -u m mkdir -p /home/m/.config/geany
cat > /home/m/.config/geany/geany.conf << 'EOF'
[build]
python_command=python3
[project]
base_path=/home/m/My-Drive/python_projects
EOF
chown -R m:m /home/m/.config

# 13. GRUB OPTIMIZATION
echo "⚡ Optimizing GRUB..."
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 mitigations=off"/' /etc/default/grub
update-grub

# 14. FINAL CONFIGURATION
echo "✨ Final configuration..."

# Set theme for user m (run as user m)
sudo -u m dbus-launch xfconf-query -c xsettings -p /Net/ThemeName -s "Windows-10-Dark" 2>/dev/null || true

# Create desktop shortcuts
cat > /home/m/Desktop/firefox.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox
Comment=Web Browser
Exec=firefox %u
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
EOF

cat > /home/m/Desktop/files.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=My Drive
Comment=Cloud Storage
Exec=thunar /home/m/My-Drive
Icon=folder
Terminal=false
Categories=Utility;FileManager;
EOF

chmod +x /home/m/Desktop/*.desktop
chown -R m:m /home/m/

# Cleanup
apt autoremove --purge -y
apt clean

# 15. COMPLETION
echo ""
echo "================================================"
echo "✅ INSTALLATION COMPLETE!"
echo "================================================"
echo ""
echo "NEXT STEPS:"
echo "1. Reboot: sudo reboot"
echo "2. Log in as user 'm' (password: 1 - change it!)"
echo ""
echo "CONFIGURE LATER:"
echo "- USB Unlock: sudo setup-usb-unlock"
echo "- Rclone: rclone config (create 'gdrive' remote)"
echo "- ProtonVPN: sudo protonvpn init"
echo ""
echo "SCHEDULED TASTS:"
echo "- Security updates: Automatic"
echo "- Monthly maintenance: 1st of each month, 3:00 AM"
echo ""
echo "Folders created:"
echo "- /home/m/My-Drive (for cloud sync)"
echo "- /home/m/launchers (custom launchers)"
echo "- /home/m/My-Drive/python_projects (Python code)"
echo "================================================"

echo "Rebooting in 10 seconds..."
sleep 10
reboot
