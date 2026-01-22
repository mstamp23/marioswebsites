#!/bin/bash

# ============================================================================
# DEBIAN 13 (TRIXIE) - COMPLETE AUTOMATED INSTALLER
# Hardware: Optimized for i9-13900F / NVIDIA GTX 1650 / 64GB RAM / 980 PRO SSD
# Features: Full app stack, security updates, rclone backup, GRUB optimization
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

# Add to sudoers and vboxsf group
usermod -aG sudo,vboxsf m 2>/dev/null || usermod -aG sudo m

# Passwordless sudo for apt commands + 30 min timeout
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
echo "📦 Configuring Debian repositories..."
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt update && apt upgrade -y

# ============================================================================
# 4. ESSENTIAL TOOLS
# ============================================================================
echo "🔧 Installing essential tools..."
apt install -y sudo wget ca-certificates unzip curl gnupg2 software-properties-common \
    apt-transport-https dirmngr lsb-release unattended-upgrades rclone build-essential \
    git speedtest-cli htop gparted ntfs-3g python3-venv python3-pip geany

# ============================================================================
# 5. HARDWARE OPTIMIZATIONS
# ============================================================================
echo "⚡ Applying hardware optimizations..."

# Intel CPU optimization
apt install -y intel-microcode thermald cpufrequtils
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils

# NVIDIA GPU drivers (if detected)
if lspci | grep -qi nvidia; then
    echo "🎮 Installing NVIDIA drivers..."
    apt install -y nvidia-driver firmware-misc-nonfree nvidia-settings
    
    # Only configure X if not in VM
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

# RAM optimization (64GB) - zRAM with zstd compression
apt install -y zram-tools
cat <<EOF > /etc/default/zram-tools
ALGO=zstd
PERCENT=25
EOF

# SSD optimization (Samsung 980 PRO)
apt install -y smartmontools
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo 'ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"' > /etc/udev/rules.d/60-scheduler.rules

# ============================================================================
# 6. XFCE DESKTOP ENVIRONMENT
# ============================================================================
echo "🖥️  Installing XFCE desktop environment..."
apt install -y xfce4 xfce4-terminal lightdm lightdm-gtk-greeter \
    xfce4-power-manager network-manager-gnome pavucontrol thunar \
    xfce4-screenshooter mousepad

# ============================================================================
# 7. LOCALES & KEYBOARD
# ============================================================================
echo "🌍 Setting up locales and keyboard..."
apt install -y locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# English keyboard first, Greek second
cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us,gr"
XKBOPTIONS="grp:alt_shift_toggle"
EOF

# Force English language for all system menus
cat <<EOF > /etc/environment
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LANGUAGE=en_US:en
EOF

# ============================================================================
# 8. WINDOWS 10 DARK THEME
# ============================================================================
echo "🎨 Installing Windows 10 Dark theme..."
apt install -y fonts-inter gtk2-engines-murrine gtk2-engines-pixbuf

# Download and install theme
cd /tmp
wget -O windows10-dark.zip https://github.com/B00merang-Project/Windows-10-Dark/archive/master.zip
unzip -o windows10-dark.zip
mkdir -p /usr/share/themes
mv Windows-10-Dark-master /usr/share/themes/Windows-10-Dark
rm windows10-dark.zip

# Set theme for user m
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

chown -R m:m /home/m/.config

# ============================================================================
# 9. APPLICATIONS INSTALLATION
# ============================================================================
echo "📱 Installing applications..."

# Firefox ESR
apt install -y firefox-esr

# Google Chrome
cd /tmp
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -y ./google-chrome-stable_current_amd64.deb || apt --fix-broken install -y
rm google-chrome-stable_current_amd64.deb

# VLC Media Player
apt install -y vlc

# qBittorrent
apt install -y qbittorrent

# yt-dlp and ffmpeg
apt install -y yt-dlp ffmpeg

# Flameshot (screenshot tool)
apt install -y flameshot

# Viber
cd /tmp
wget https://download.cdn.viber.com/desktop/Linux/viber.deb
apt install -y ./viber.deb || apt --fix-broken install -y
rm viber.deb

# ProtonVPN
wget -q -O - https://repo.protonvpn.com/debian/deb.gpg | gpg --dearmor > /usr/share/keyrings/proton.gpg
echo "deb [signed-by=/usr/share/keyrings/proton.gpg] https://repo.protonvpn.com/debian stable main" > /etc/apt/sources.list.d/protonvpn.list
apt update
apt install -y protonvpn-stable-release protonvpn-cli protonvpn-app

# MenuLibre (menu editor)
apt install -y menulibre

# Firewall (UFW)
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw enable

# ============================================================================
# 9A. FAIL2BAN - INTRUSION PREVENTION
# ============================================================================
echo "🛡️  Installing fail2ban for intrusion prevention..."
apt install -y fail2ban

# Create custom configuration
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
# Ban for 1 hour after 5 failed attempts within 10 minutes
bantime = 3600
findtime = 600
maxretry = 5

# Don't ban localhost
ignoreip = 127.0.0.1/8 ::1

# Email alerts (optional - configure if needed)
# destemail = your-email@example.com
# sendername = Fail2Ban
# action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5

[sshd-ddos]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 10

# Protect against authentication failures
[pam-generic]
enabled = true
port = all
banaction = iptables-multiport
logpath = /var/log/auth.log
maxretry = 5

# Protect against brute force on any service
[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = iptables-allports
bantime = 86400
findtime = 86400
maxretry = 3
EOF

# Ensure fail2ban works with UFW (not iptables)
cat <<EOF > /etc/fail2ban/jail.d/ufw.conf
[DEFAULT]
banaction = ufw
EOF

# Start and enable fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo "✅ Fail2ban configured and running"
echo "   - Protects SSH, PAM, and system authentication"
echo "   - Does NOT interfere with qBittorrent, ProtonVPN, or normal traffic"
echo "   - Bans attackers for 1 hour after 5 failed login attempts"
echo "   - Check status: sudo fail2ban-client status"

# ClamAV Antivirus
apt install -y clamav clamav-daemon clamtk
systemctl stop clamav-freshclam
freshclam
systemctl start clamav-freshclam
systemctl enable clamav-freshclam

# ============================================================================
# 9B. USB AUTHENTICATION (PAM-USB) - INSTALL BUT DON'T CONFIGURE
# ============================================================================
echo "🔐 Installing USB authentication (pam-usb)..."
apt install -y pamusb-tools libpam-usb

echo ""
echo "⚠️  USB AUTHENTICATION INSTALLED BUT NOT CONFIGURED"
echo "   This allows login via USB drive (for physical machines only)"
echo ""
echo "   📝 TO CONFIGURE LATER (do NOT do this in VMs):"
echo "   1. Insert your USB drive"
echo "   2. Run: sudo pamusb-conf --add-device YourUSBName"
echo "   3. Run: sudo pamusb-conf --add-user m"
echo "   4. Edit /etc/pam.d/common-auth and add at the TOP:"
echo "      auth sufficient pam_usb.so"
echo "   5. Test with: sudo pamusb-check m"
echo ""
echo "   ⚡ This works alongside your password - you can use EITHER USB OR password"
echo "   🚫 DO NOT configure this in VirtualBox VMs!"
echo ""

# ============================================================================
# 10. SPEEDTEST-CLI LAUNCHER
# ============================================================================
echo "🌐 Creating speedtest launcher..."
cat <<'EOF' > /home/m/launchers/speedtest.sh
#!/bin/bash
xfce4-terminal --hold -e "speedtest-cli"
EOF
chmod +x /home/m/launchers/speedtest.sh

# ============================================================================
# 11. PYTHON VIRTUAL ENVIRONMENT
# ============================================================================
echo "🐍 Setting up Python environment..."
sudo -u m python3 -m venv /home/m/My-Drive/python-env
sudo -u m cat <<'EOF' > /home/m/My-Drive/activate-python.sh
#!/bin/bash
source /home/m/My-Drive/python-env/bin/activate
EOF
chmod +x /home/m/My-Drive/activate-python.sh

# ============================================================================
# 12. RCLONE CONFIGURATION & SYSTEMD TIMER (DAILY AT 3 AM)
# ============================================================================
echo "☁️  Setting up rclone daily backup..."

cat <<EOF > /etc/systemd/system/rclone-sync.service
[Unit]
Description=Daily Rclone Sync for user m
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=m
# Sync local folder to GDrive, skipping system files
ExecStart=/usr/bin/rclone sync /home/m/My-Drive gdrive:My-Drive --exclude "venv/**" --exclude ".git/**" --exclude "python-env/**" --verbose --log-file=/var/log/rclone-sync.log
# Lower priority so it doesn't slow down CPU during work
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
EOF

cat <<EOF > /etc/systemd/system/rclone-sync.timer
[Unit]
Description=Run Rclone Sync every day at 03:00 AM

[Timer]
# Runs at 3 AM every day
OnCalendar=*-*-* 03:00:00
# Ensures it runs even if the computer was off at 3 AM
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable rclone-sync.timer

echo "⚠️  IMPORTANT: After installation, configure rclone with:"
echo "   sudo -u m rclone config"
echo "   Create a remote named 'gdrive' pointing to your Google Drive"

# ============================================================================
# 13. UNATTENDED SECURITY UPDATES
# ============================================================================
echo "🔒 Configuring automatic security updates..."

cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=\${distro_codename}-security";
};
Unattended-Upgrade::Package-Blacklist { };
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# ============================================================================
# 14. SYSTEM MAINTENANCE SCRIPT
# ============================================================================
echo "🧹 Creating system maintenance script..."

cat <<'EOF' > /usr/local/bin/system-maintenance
#!/bin/bash
echo "🔄 Running system maintenance..."
apt update
apt upgrade -y
apt autoremove -y
apt autoclean
apt clean
echo "✅ System maintenance completed - $(date)"
EOF
chmod +x /usr/local/bin/system-maintenance

# Schedule monthly maintenance
cat <<EOF > /etc/systemd/system/system-maintenance.service
[Unit]
Description=System Maintenance

[Service]
Type=oneshot
ExecStart=/usr/local/bin/system-maintenance
EOF

cat <<EOF > /etc/systemd/system/system-maintenance.timer
[Unit]
Description=Run system maintenance monthly

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable system-maintenance.timer

# ============================================================================
# 15. DISABLE UNNECESSARY SERVICES
# ============================================================================
echo "⚙️  Disabling unnecessary services..."
systemctl disable bluetooth.service 2>/dev/null || true
systemctl mask bluetooth.service 2>/dev/null || true
systemctl disable cups.service 2>/dev/null || true
systemctl disable cups-browsed.service 2>/dev/null || true

# ============================================================================
# 16. GRUB OPTIMIZATION
# ============================================================================
echo "🚀 Optimizing GRUB bootloader..."

sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 mitigations=off"/' /etc/default/grub

update-grub

# ============================================================================
# 17. SESSION AUTOSTART OPTIMIZATION
# ============================================================================
echo "🎯 Optimizing session autostart..."

# Disable unnecessary autostart items
sudo -u m mkdir -p /home/m/.config/autostart

for app in at-spi-dbus-bus blueman clipman notes print-applet; do
    if [ -f "/etc/xdg/autostart/${app}.desktop" ]; then
        sudo -u m cat <<EOF > /home/m/.config/autostart/${app}.desktop
[Desktop Entry]
Hidden=true
EOF
    fi
done

# ============================================================================
# 18. FINAL CLEANUP & OWNERSHIP
# ============================================================================
echo "🧼 Final cleanup..."
chown -R m:m /home/m/
apt autoremove -y
apt clean

# ============================================================================
# 19. ENABLE GRAPHICAL TARGET
# ============================================================================
systemctl set-default graphical.target
systemctl enable lightdm

# ============================================================================
# 20. COMPLETION & REBOOT
# ============================================================================
cat <<EOF

========================================
✅ INSTALLATION COMPLETE!
========================================

🎉 Your Debian 13 system is ready!

📋 IMMEDIATE NEXT STEPS:
1. Configure rclone: sudo -u m rclone config
   → Create remote named 'gdrive' for Google Drive
2. Set up ProtonVPN: protonvpn-app
3. Activate Python env: source /home/m/My-Drive/activate-python.sh

🔐 USB AUTHENTICATION (Optional - Physical Machines Only):
   DO NOT configure in VMs! Only on real hardware.
   1. Insert USB drive
   2. sudo pamusb-conf --add-device YourUSBName
   3. sudo pamusb-conf --add-user m
   4. Edit /etc/pam.d/common-auth (add at TOP):
      auth sufficient pam_usb.so
   Works alongside password - you can use EITHER USB OR password

📊 SYSTEM FEATURES:
✓ XFCE Desktop with Windows 10 Dark theme
✓ Hardware optimizations (i9/NVIDIA/SSD)
✓ Security-only auto-updates (daily)
✓ System maintenance (monthly)
✓ Rclone backup (daily at 3 AM)
✓ Firewall enabled (UFW)
✓ Fail2ban intrusion prevention
✓ Fast GRUB boot (1 second)
✓ All essential applications installed
✓ pam-usb installed (configure manually)
✓ English menus with Greek keyboard available

📱 INSTALLED APPS:
• Firefox ESR, Google Chrome
• VLC Media Player, qBittorrent
• Flameshot, Viber, ProtonVPN
• yt-dlp, ffmpeg, Geany
• ClamAV Antivirus, MenuLibre

⚙️  OPTIMIZATIONS:
• CPU: Performance governor
• RAM: 25% zRAM with zstd
• SSD: None scheduler for NVMe
• Swappiness: 10
• NVIDIA: ForceFullCompositionPipeline
• Language: English (US) system-wide
• Keyboards: US (primary), Greek (Alt+Shift)

🔄 System will reboot in 10 seconds...
========================================

EOF

sleep 10
reboot
