#!/bin/bash
set -euo pipefail

# Disable IPv6 via sysctl

# Append settings to sysctl.conf to disable IPv6
cat <<EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

# Apply the sysctl changes immediately
sysctl -p

# Disable IPv6 for current session without reboot
for iface in $(ls /proc/sys/net/ipv6/conf/); do
  sysctl -w net.ipv6.conf.$iface.disable_ipv6=1
done

# Disable IPv6 at the GRUB bootloader level (this will take effect on the next reboot)
sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub

# Update GRUB to apply the new boot parameters (but don't reboot)
update-grub

# Force apt to use IPv4
cat <<EOF >> /etc/apt/apt.conf.d/99force-ipv4
Acquire::ForceIPv4 "true";
EOF

sudo -u ubuntu -i <<'EOF'
set -euo pipefail

# Function to check if a package is installed
is_installed() {
    dpkg -l | grep -q "^ii  $1"
}

# Function to install a package if it is not installed
install_if_missing() {
    if ! is_installed "$1"; then
        echo "Installing $1..."
        sudo apt-get install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

sudo apt-get update

# Packages to check and install
for package in libc6 groff less unzip curl ca-certificates gnupg; do
    install_if_missing "$package"
done

# Check if AWS Cli is installed and if not install and verify it
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    if [ $? -ne 0 ]; then
        echo "Failed to download AWS CLI"
        exit 1
    fi

    unzip awscliv2.zip
    if [ $? -ne 0 ]; then
        echo "Failed to unzip AWS CLI"
        exit 1
    fi

    sudo ./aws/install
    if [ $? -ne 0 ]; then
        echo "Failed to install AWS CLI"
        exit 1
    fi

    aws --version
    if [ $? -ne 0 ]; then
        echo "AWS CLI installation verification failed"
        exit 1
    fi
fi

curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"

sudo dpkg -i session-manager-plugin.deb

sudo hostnamectl set-hostname bastion

# disable swap memory
sudo swapoff -a

# add the command to crontab to make it persistent across reboots
(crontab -l 2>/dev/null || true; echo "@reboot /sbin/swapoff -a") | crontab -

echo -e "Done bootstrapping Bastion.\n"
EOF
