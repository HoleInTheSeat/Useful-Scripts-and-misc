#!/bin/bash

# Kill running DW client
pkill -f "dwspectrum"

# Ensure curl, wget, and jq are installed
apt update && apt install curl wget jq -y

#DW Downloads API
API_URL="https://dwspectrum.digital-watchdog.com/api/utils/downloads"

# Get JSON and extract version + buildNumber + path for Linux client installer
response=$(curl -s "$API_URL")
buildNumber=$(echo "$response" | jq -r '.buildNumber')
client_path=$(echo "$response" | jq -r '.installers[] | select(.platform=="linux_x64" and .appType=="client") | .path')

# Construct the full URL
base_url="https://updates.digital-watchdog.com/digitalwatchdog/$buildNumber/"
full_url="${base_url}${client_path}"

if [ -n "$full_url" ] && [[ "$full_url" == https* ]]; then
    echo "Latest Linux client URL: $full_url"
    wget "$full_url"
else
    echo "Failed to find Linux client URL."
fi
dpkg -i dwspectrum-client-* && apt --fix-broken install -y && rm dwspectrum-client-*

# Backup old autostart
cp /etc/xdg/autostart/client-bin.desktop /home/wcr7/client-bin.desktop.bak

# Get current latest version dir
dwcurver=$(ls /opt/digitalwatchdog/client/ | sort -V | tail -n 1)

# Fix autostart
sed -i "s|Exec=.*|Exec=/opt/digitalwatchdog/client/$dwcurver/bin/client-bin|g" /etc/xdg/autostart/client-bin.desktop

# Reboot
reboot now