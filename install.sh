#!/bin/bash
# ============================================================================
# DEBIAN 13 (TRIXIE) UNIVERSAL INSTALLER - BEAST & LAPTOP EDITION
# Target: Secure, Snappy, Professional, Stable
# ============================================================================

set -e
trap 'echo "❌ Error on line $LINENO. Check /var/log/debian-install.log"; exit 1' ERR

# Ensure log directory exists
mkdir -p /var/log
exec > >(tee -a /var/log/debian-install.log)
exec 2>&1

if [ "$EUID" -ne 0 ]; then echo "❌ Please run as root"; exit 1; fi

echo "=========================================="
echo "🚀 INITIALIZING DEBIAN 13 PROFESSIONAL SETUP"
echo "=========================================="

# 1. USER CREATION (Password set to "1")
if ! id -u m &>/dev/null; then
    echo "👤 Creating user 'm'..."
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd 
fi

# 2. SOURCES & UPDATES
echo "📦 Configuring high-performance APT repositories..."
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt update && apt upgrade -y

# 3. LOCALES & KEYBOARD (English Menus, Greek Typing)
echo "🌐 Configuring Locales..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
localectl set-x11-keymap us,gr pc105 "" grp:alt_shift_toggle

# 4. PRIVILEGES (30m Timeout + No Pass for Apt)
echo "👤 Setting up Pro-Sudoers..."
cat <<EOF > /etc/sudoers.d/m
m ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/systemctl
Defaults:m timestamp_timeout=30
EOF
chmod 0440 /etc/sudoers.d/m
adduser m sudo || true

# 5. HARDWARE OPTIMIZATION (i9 & NVIDIA GTX 1650)
echo "🔧 Detecting Hardware..."

# Intel i9 Thermal & Microcode
if grep -q "Intel" /proc/cpuinfo; then
    apt install -y intel-microcode thermald
    systemctl enable thermald
fi

# NVIDIA GTX 1650 & Screen Tearing Fix
if lspci | grep -qi nvidia; then
    apt install -y nvidia-detect linux-headers-amd64
    NVIDIA_PKG=$(nvidia-detect 2>/dev/null | grep -o 'nvidia-driver' || echo "nvidia-driver")
    apt install -y $NVIDIA_PKG firmware-misc-nonfree nvidia-settings
    # Anti-tearing for XFCE
    mkdir -p /etc/X11/xorg.conf.d/
    cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    VendorName "NVIDIA Corporation"
    Option "NoLogo" "true"
    Option "ForceFullCompositionPipeline" "on"
EndSection
EOF
fi

# RAM: zRAM (16GB for 64GB RAM)
apt install -y zram-tools
echo "ALGO=zstd" > /etc/default/zram-tools
echo "PERCENT=25" >> /etc/default/zram-tools
systemctl restart zram-tools

# SSD: Samsung 980 PRO Health
apt install -y smartmontools
systemctl enable fstrim.timer
echo "vm.swappiness=10" >> /etc/sysctl.conf

# Tmpfs (Save SSD writes)
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

# 6. SECURITY: USB LOCK, FIREWALL, UPDATES
apt install -y unattended-upgrades ufw libpam-usb pamusb-tools clamtk
cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=\${distro_codename}-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
systemctl enable unattended-upgrades
ufw --force enable
ufw default deny incoming
ufw default allow outgoing

# 7. RCLONE AUTOMATION
cat <<EOF > /etc/systemd/system/rclone-sync.service
[Unit]
Description=Daily Rclone Sync for user m
After=network-online.target

[Service]
Type=oneshot
User=m
ExecStart=/usr/bin/rclone sync /home/m/My-Drive gdrive:My-Drive --exclude "venv/**" --exclude ".git/**"
Nice=19
EOF

cat <<EOF > /etc/systemd/system/rclone-sync.timer
[Unit]
Description=Run Rclone Sync daily at 03:00 AM

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable rclone-sync.timer

# 8. CORE SOFTWARE & CHROME
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
apt install -y /tmp/google-chrome-stable_current_amd64.deb

apt install -y --no-install-recommends \
    xfce4 xfce4-terminal thunar xfce4-settings xfce4-panel xfce4-session \
    xfce4-power-manager network-manager-gnome lightdm lightdm-gtk-greeter \
    fonts-inter pavucontrol xfce4-screenshooter

apt install -y \
    firefox-esr qbittorrent vlc yt-dlp ffmpeg flameshot \
    menulibre rclone geany cpufrequtils ntfs-3g hdparm \
    gparted htop neofetch lm-sensors vulkan-tools

# KVM Virtualization
apt install -y --no-install-recommends qemu-system qemu-utils libvirt-daemon-system virt-manager bridge-utils
usermod -aG libvirt,kvm m

# 9. FINAL CLEANUP
systemctl mask bluetooth.service cups.service cups-browsed.service
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub

mkdir -p /home/m/My-Drive /home/m/launchers /home/m/Downloads
chown -R m:m /home/m/
apt autoremove -y && apt autoclean

echo "=========================================="
echo "✅ SUCCESS! INSTALLATION LOG: /var/log/debian-install.log"
echo "=========================================="
echo "🚀 Now we are rebooting..."
sleep 5
reboot
