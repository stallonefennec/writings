#!/bin/bash

# Stop on any error
set -e

echo "Starting NaiveProxy and Caddy installation..."

# 1. Uninstall any existing Caddy and Go installations
echo "Uninstalling existing Caddy and old Go..."
if systemctl list-units --type=service | grep -q caddy.service; then
    sudo systemctl stop caddy || true
fi
sudo apt-get purge -y caddy golang-go
sudo apt-get autoremove -y
sudo rm -rf /usr/local/go

# 2. Install the latest Go language environment
echo "Installing latest Go..."
# Fetch the latest Go version and download it
GO_LATEST_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
GO_FILENAME="${GO_LATEST_VERSION}.linux-amd64.tar.gz"
DOWNLOAD_URL="https://go.dev/dl/${GO_FILENAME}"

echo "Downloading ${DOWNLOAD_URL}"
curl -L -o "/tmp/${GO_FILENAME}" "${DOWNLOAD_URL}"

echo "Extracting Go..."
sudo tar -C /usr/local -xzf "/tmp/${GO_FILENAME}"
rm "/tmp/${GO_FILENAME}"

# Set up Go environment for the build
export PATH=$PATH:/usr/local/go/bin

# Verify Go installation
/usr/local/go/bin/go version

# 3. Build Caddy with the forwardproxy plugin using xcaddy
echo "Building Caddy with forwardproxy plugin..."
# Install xcaddy
/usr/local/go/bin/go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# Build Caddy
$HOME/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2

# 4. Install the new Caddy binary
echo "Installing the newly built Caddy..."
sudo mv ./caddy /usr/bin/caddy
sudo chmod +x /usr/bin/caddy

# 5. Set up Caddy user and systemd service
echo "Setting up Caddy user and service..."
# Create caddy user and group
sudo groupadd --system caddy || true
sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy || true

# Create Caddyfile directory if it doesn't exist
sudo mkdir -p /etc/caddy
sudo chown -R caddy:caddy /etc/caddy

# Create the Caddyfile
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
{
    order forward_proxy before file_server
}

:443, fennec-lucky.com {
    tls stalloneiv@gmail.com
    forward_proxy {
        basic_auth stallone 198964
        probe_resistance
    }
    file_server {
        root /var/www/html
    }
}
EOF
sudo chown caddy:caddy /etc/caddy/Caddyfile

# Create the systemd service file
sudo tee /etc/systemd/system/caddy.service > /dev/null <<'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# 6. Download and install NaiveProxy
echo "Downloading and installing NaiveProxy..."
LATEST_VERSION=$(curl -s "https://api.github.com/repos/klzgrad/naiveproxy/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="linux-x64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="linux-arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

NAIVE_FILENAME="naiveproxy-${LATEST_VERSION}-${ARCH}.tar.xz"
DOWNLOAD_URL="https://github.com/klzgrad/naiveproxy/releases/download/${LATEST_VERSION}/${NAIVE_FILENAME}"

echo "Downloading from ${DOWNLOAD_URL}"
sudo rm -f "/tmp/${NAIVE_FILENAME}"
sudo curl -L -o "/tmp/${NAIVE_FILENAME}" "${DOWNLOAD_URL}"

sudo tar -xf "/tmp/${NAIVE_FILENAME}" -C /tmp
sudo mv "/tmp/naiveproxy-${LATEST_VERSION}-${ARCH}/naive" /usr/local/bin/
sudo chmod +x /usr/local/bin/naive

# 7. Create the file server root directory
sudo mkdir -p /var/www/html
sudo chown -R caddy:caddy /var/www/html

# 8. Reload and start Caddy
echo "Reloading systemd and starting Caddy..."
sudo systemctl daemon-reload
sudo systemctl enable --now caddy

echo "Installation complete."
sudo systemctl status caddy
