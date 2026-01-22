#!/bin/bash
# ============================================================================
# DEBIAN 13 (TRIXIE) PROFESSIONAL INSTALLER - CLEAN VERSION
# ============================================================================

set -e
trap 'echo "❌ Error on line $LINENO. Check /var/log/debian-install.log"; exit 1' ERR

# 1. LOGGING & ROOT CHECK
mkdir -p /var/log
exec > >(tee -a /var/log/debian-install.log)
exec 2>&1
if [ "$EUID" -ne 0 ]; then echo "❌ Run as root"; exit 1; fi

# 2. CORE DEPENDENCIES & USER (Fixes Line 48)
echo "📦 Installing sudo and creating user m..."
apt update
apt install -y sudo 
mkdir -p /etc/sudoers.d

if ! id -u m &>/dev/null; then
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd
fi

echo 'm ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/systemctl' > /etc/sudoers.d/m
echo 'Defaults:m timestamp_timeout=30' >> /etc/sudoers.d/m
chmod 0440 /etc/sudoers.d/m
adduser m sudo || true

# 3. SOURCES & UPDATES
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
apt update && apt upgrade -y

# 4. HARDWARE OPTIMIZATION (i9 & NVIDIA)
echo "🔧 Optimizing Hardware..."
if grep -q "Intel" /proc/cpuinfo; then
    apt install -y intel-microcode thermald
    systemctl enable thermald
fi

if lspci | grep -qi nvidia; then
    apt install -y nvidia-detect linux-headers-amd64
    NVIDIA_PKG=$(nvidia-detect 2>/dev/null | grep -o 'nvidia-driver' || echo "nvidia-driver")
    apt install -y $NVIDIA_PKG firmware-misc-nonfree nvidia-settings
    mkdir -p /etc/X11/xorg.conf.d/
    cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "ForceFullCompositionPipeline" "on"
EndSection
EOF
fi

# 5. RAM & SSD (64GB RAM / Samsung 980 PRO)
apt install -y zram-tools smartmontools
echo "ALGO=zstd" > /etc/default/zram-tools
echo "PERCENT=25" >> /etc/default/zram-tools
systemctl restart zram-tools
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount
echo "vm.swappiness=10" >> /etc/sysctl.conf

# 6. LOCALES & KEYBOARD
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
localectl set-x11-keymap us,gr pc105 "" grp:alt_shift_toggle

# 7. SOFTWARE STACK
echo "🌐 Installing Chrome & XFCE..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
apt install -y /tmp/google-chrome-stable_current_amd64.deb

apt install -y --no-install-recommends \
    xfce4 xfce4-terminal thunar xfce4-settings xfce4-panel xfce4-session \
    xfce4-power-manager network-manager-gnome lightdm lightdm-gtk-greeter \
    fonts-inter pavucontrol rclone vlc firefox-esr qbittorrent yt-dlp flameshot \
    geany cpufrequtils ntfs-3g hdparm gparted htop lm-sensors vulkan-tools

# 8. VIRTUALIZATION & SECURITY
apt install -y qemu-system qemu-utils libvirt-daemon-system virt-manager bridge-utils
usermod -aG libvirt,kvm m
apt install -y unattended-upgrades ufw libpam-usb pamusb-tools
ufw --force enable
ufw default deny incoming

# 9. FINAL REBOOT
systemctl mask bluetooth.service cups.service
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub
chown -R m:m /home/m/
apt autoremove -y

echo "✅ SUCCESS! REBOOTING..."
sleep 5
reboot
