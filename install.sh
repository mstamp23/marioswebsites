#!/bin/bash
# ============================================================================
# DEBIAN 13 (TRIXIE) - THE "SMART BEAST" INSTALLER
# Logic: Auto-detects VM vs. Physical to prevent GUI crashes
# ============================================================================

set -e
trap 'echo "❌ Error on line $LINENO. Check /var/log/debian-install.log"; exit 1' ERR

# 1. LOGGING & ROOT CHECK
mkdir -p /var/log
exec > >(tee -a /var/log/debian-install.log)
exec 2>&1
if [ "$EUID" -ne 0 ]; then echo "❌ Run as root"; exit 1; fi

# 2. CORE TOOLS & USER (Password: 1)
apt update && apt install -y sudo wget ca-certificates
mkdir -p /etc/sudoers.d
if ! id -u m &>/dev/null; then
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd
fi
echo 'm ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/m
chmod 0440 /etc/sudoers.d/m

# 3. SOURCES
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
apt update && apt upgrade -y

# 4. HARDWARE: i9 & NVIDIA (WITH VM GUARD)
echo "🔧 Configuring Hardware..."
apt install -y intel-microcode thermald linux-headers-amd64
systemctl enable thermald || true

if lspci | grep -qi nvidia; then
    echo "🎮 NVIDIA GPU Detected."
    apt install -y nvidia-driver firmware-misc-nonfree nvidia-settings
    
    # Check if we are on Real Hardware or a VM
    if ! systemd-detect-virt | grep -q 'oracle\|vmware\|qemu'; then
        echo "🖥️ REAL BEAST DETECTED: Applying NVIDIA Pipeline..."
        mkdir -p /etc/X11/xorg.conf.d/
        cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "ForceFullCompositionPipeline" "on"
EndSection
EOF
    else
        echo "☁️ VM DETECTED: Skipping NVIDIA Xorg config to prevent crash."
        apt install -y virtualbox-guest-x11 || true
    fi
fi

# 5. RAM, SSD, LOCALES & KEYBOARD
apt install -y zram-tools smartmontools
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us,gr"
XKBOPTIONS="grp:alt_shift_toggle"
EOF

# 6. DESKTOP INSTALL (Full packages for stability)
echo "🖥️ Installing XFCE & Chrome..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
apt install -y /tmp/google-chrome-stable_current_amd64.deb || true

apt install -y xfce4 xfce4-terminal lightdm lightdm-gtk-greeter \
    network-manager-gnome pavucontrol fonts-inter rclone vlc firefox-esr

# 7. GUI ACTIVATION
systemctl set-default graphical.target
systemctl enable lightdm
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager

# 8. FINAL CLEANUP & REBOOT
apt autoremove -y
chown -R m:m /home/m/
update-grub

echo "✅ SUCCESS! REBOOTING..."
sleep 5
reboot
