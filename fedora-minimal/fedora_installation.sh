sudo dnf install @xfce-desktop-environment -y   
sudo systemctl set-default graphical.target   
reboot



# Enable RPM Fusion repos for codecs
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-43.noarch.rpm \
https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-43.noarch.rpm

# Install Firefox, Mousepad, multimedia codecs, graphics/audio drivers, and clipboard
sudo dnf install -y firefox mousepad \
ffmpeg gstreamer1-plugins-{bad-free,good,libav} \
libva libvdpau mesa-dri-drivers mesa-vdpau-drivers \
spice-vdagent pulseaudio-utils alsa-utils
