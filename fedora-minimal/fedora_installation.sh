sudo dnf install @xfce-desktop-environment -y   
sudo systemctl set-default graphical.target   
reboot


# Enable RPM Fusion repos
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-43.noarch.rpm \
https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-43.noarch.rpm

# Install Firefox, Mousepad, codecs, drivers, clipboard — allow erasing conflicting packages
sudo dnf install -y --allowerasing firefox mousepad \
ffmpeg gstreamer1-plugins-{bad-free,good,ugly} \
libva libvdpau mesa-dri-drivers mesa-vdpau-drivers \
spice-vdagent pulseaudio-utils alsa-utils
