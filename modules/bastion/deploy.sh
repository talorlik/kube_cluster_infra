#!/bin/bash
set -euo pipefail

sudo -u ubuntu -i <<'EOF'

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

echo -e "Done bootstrapping Bastion.\n"
EOF
