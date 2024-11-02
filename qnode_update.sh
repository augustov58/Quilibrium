#!/bin/bash

# Define variables
RELEASE_LIST_URL="https://releases.quilibrium.com/release"
DOWNLOAD_BASE_URL="https://releases.quilibrium.com"
NODE_DIR="$HOME/ceremonyclient/node"
SERVICE_FILE="/lib/systemd/system/ceremonyclient.service"

# Step 1: Get the latest release version for linux-amd64
latest_version=$(curl -s "$RELEASE_LIST_URL" | \
  grep -E '^node-[0-9.]+-linux-amd64$' | \
  sed -E 's/^node-([0-9.]+)-linux-amd64$/\1/' | \
  sort -V | \
  tail -n1)

if [ -z "$latest_version" ]; then
  echo "Unable to determine the latest version."
  exit 1
fi

latest_release="node-$latest_version-linux-amd64"

# Step 2: Get the installed version from the node directory
installed_node=$(ls "$NODE_DIR" | grep -E '^node-[0-9.]+-linux-amd64$' | sort -V | tail -n1)

if [ -z "$installed_node" ]; then
  echo "No installed node version found in $NODE_DIR."
  exit 1
fi

installed_version=$(echo "$installed_node" | sed -E 's/^node-([0-9.]+)-linux-amd64$/\1/')

echo "Latest version: $latest_version"
echo "Installed version: $installed_version"

# Step 3: Compare versions
if [ "$installed_version" == "$latest_version" ]; then
  echo "The latest version is already installed."
  exit 0
fi

# Step 4: Download new release and signatures
echo "Downloading new release and signatures..."

# Fetch the list of files for the latest version and linux-amd64
files_to_download=$(curl -s "$RELEASE_LIST_URL" | \
  grep -E "^node-$latest_version-linux-amd64(\..*)?$" | \
  awk '{print $1}')

if [ -z "$files_to_download" ]; then
  echo "No files found to download for version $latest_version."
  exit 1
fi

cd "$NODE_DIR" || exit

for file in $files_to_download; do
  wget "$DOWNLOAD_BASE_URL/$file"
done

# **Set executable permissions on the node binary**
chmod +x "node-$latest_version-linux-amd64"

# Step 5: Stop the node
echo "Stopping ceremonyclient service..."
sudo systemctl stop ceremonyclient

# Step 6: Update the service file
echo "Updating service file..."
sudo sed -i.bak "s#^\(ExecStart=.*node-\)[^ ]*\(-linux-amd64.*\)#\1$latest_version\2#" "$SERVICE_FILE"

# Reload systemd configuration
sudo systemctl daemon-reload

# Step 7: Ask user to restart the node
read -rp "Do you want to restart the node now? (yes/no): " answer

if [[ "$answer" =~ ^[Yy][Ee][Ss]$ || "$answer" =~ ^[Yy]$ ]]; then
  echo "Restarting ceremonyclient service..."
  sudo systemctl restart ceremonyclient
fi

echo "Node has been updated to $latest_version"
