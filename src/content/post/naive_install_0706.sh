#!/bin/bash

# Stop on any error
set -e

# --- 預設值設定 (Default Settings) ---
DEFAULT_DOMAIN="fennec-lucky.com"
DEFAULT_EMAIL="stalloneiv@gmail.com"
DEFAULT_USERNAME="stallone"
DEFAULT_PASSWORD="198964"

# --- 互動式設定 (Interactive Setup) ---
echo "--- NaiveProxy & Caddy Interactive Setup ---"
echo "Please enter your configuration details."
echo "Press Enter to use the default value shown in brackets."
echo

# 提示使用者輸入，如果為空則使用預設值
read -p "Enter your domain [${DEFAULT_DOMAIN}]: " CUSTOM_DOMAIN
DOMAIN=${CUSTOM_DOMAIN:-$DEFAULT_DOMAIN}

read -p "Enter your email for TLS [${DEFAULT_EMAIL}]: " CUSTOM_EMAIL
EMAIL=${CUSTOM_EMAIL:-$DEFAULT_EMAIL}

read -p "Enter the username [${DEFAULT_USERNAME}]: " CUSTOM_USERNAME
USERNAME=${CUSTOM_USERNAME:-$DEFAULT_USERNAME}

read -p "Enter the password [${DEFAULT_PASSWORD}]: " CUSTOM_PASSWORD
PASSWORD=${CUSTOM_PASSWORD:-$DEFAULT_PASSWORD}

# --- 設定總覽 (Configuration Summary) ---
echo
echo "-------------------------------------"
echo "Configuration to be used:"
echo "Domain:   ${DOMAIN}"
echo "Email:    ${EMAIL}"
echo "Username: ${USERNAME}"
echo "Password: ${PASSWORD}"
echo "-------------------------------------"
read -p "Press Enter to continue, or Ctrl+C to cancel."
echo

# --- 正式開始安裝 ---
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
GO_LATEST_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
GO_FILENAME="${GO_LATEST_VERSION}.linux-amd64.tar.gz"
DOWNLOAD_URL="https://go.dev/dl/${GO_FILENAME}"
echo "Downloading ${DOWNLOAD_URL}"
curl -L -o "/tmp/${GO_FILENAME}" "${DOWNLOAD_URL}"
echo "Extracting Go..."
sudo tar -C /usr/local -xzf "/tmp/${GO_FILENAME}"
rm "/tmp/${GO_FILENAME}"
export PATH=$PATH:/usr/local/go/bin
/usr/local/go/bin/go version

# 3. Build Caddy with the forwardproxy plugin using xcaddy
echo "Building Caddy with forwardproxy plugin..."
/usr/local/go/bin/go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
$HOME/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2

# 4. Install the new Caddy binary
echo "Installing the newly built Caddy..."
sudo mv ./caddy /usr/bin/caddy
sudo chmod +x /usr/bin/caddy

# 5. Set up Caddy user and systemd service
echo "Setting up Caddy user and service..."
sudo groupadd --system caddy || true
sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy || true
sudo mkdir -p /etc/caddy
sudo chown -R caddy:caddy /etc/caddy
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
{
    order forward_proxy before file_server
}

:443, ${DOMAIN} {
    tls ${EMAIL}
    forward_proxy {
        basic_auth ${USERNAME} ${PASSWORD}
        probe_resistance
    }
    file_server {
        root /var/www/html
    }
}
EOF
sudo chown caddy:caddy /etc/caddy/Caddyfile
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

# 7. Create web directory and download content
echo "Creating web directory and downloading content..."
sudo mkdir -p /var/www/html
WEBSITE_URL="https://raw.githubusercontent.com/stallonefennec/writings/main/src/content/post/bigdays.tar.gz"
WEBSITE_ARCHIVE="/tmp/bigdays.tar.gz"
echo "Downloading website content from ${WEBSITE_URL}"
sudo curl -L -o "${WEBSITE_ARCHIVE}" "${WEBSITE_URL}"
echo "Extracting content to /var/www/html/"
sudo tar -xzf "${WEBSITE_ARCHIVE}" -C /var/www/html/
echo "Setting ownership for web content..."
sudo chown -R caddy:caddy /var/www/html
echo "Cleaning up temporary archive..."
sudo rm "${WEBSITE_ARCHIVE}"

# 8. Reload and start Caddy
echo "Reloading systemd and starting Caddy..."
sudo systemctl daemon-reload
sudo systemctl enable --now caddy

echo "Installation complete."
sudo systemctl status caddy