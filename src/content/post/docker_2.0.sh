#!/bin/bash

# 确保脚本以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo "该脚本需要root权限，请使用sudo命令运行" 1>&2
   exit 1
fi

# 更新软件包列表
echo "正在更新软件包列表..."
apt update

# 安装Docker
echo "正在安装Docker..."
apt install -y docker.io
apt install -y docker-compose-plugin

echo "Docker安装完成。"

# Pull the Docker image
docker pull pocat/naiveproxy

# Create directories
mkdir -p /etc/naiveproxy /var/www/html /var/log/caddy

# 设置默认值
DEFAULT_LISTEN_PORT="48658"
DEFAULT_DOMAIN_NAME="luckydorothy.com"
DEFAULT_EMAIL_ADDRESS="stalloneiv@gmail.com"
DEFAULT_USERNAME="stallone"
DEFAULT_PASSWORD="198964"

# 获取用户输入，如果为空则使用默认值
read -p "请输入监听端口 (默认: $DEFAULT_LISTEN_PORT): " LISTEN_PORT
LISTEN_PORT="${LISTEN_PORT:-$DEFAULT_LISTEN_PORT}"

read -p "请输入域名 (默认: $DEFAULT_DOMAIN_NAME): " DOMAIN_NAME
DOMAIN_NAME="${DOMAIN_NAME:-$DEFAULT_DOMAIN_NAME}"

read -p "请输入邮箱地址 (用于获取TLS证书, 默认: $DEFAULT_EMAIL_ADDRESS): " EMAIL_ADDRESS
EMAIL_ADDRESS="${EMAIL_ADDRESS:-$DEFAULT_EMAIL_ADDRESS}"

read -p "请输入用户名 (用于基本身份验证, 默认: $DEFAULT_USERNAME): " USERNAME
USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

read -p "请输入密码 (用于基本身份验证, 默认: $DEFAULT_PASSWORD): " PASSWORD
PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"

# 创建 Caddyfile (使用用户输入或默认值)
cat > /etc/naiveproxy/Caddyfile <<EOF
{
  admin off
  log {
    output file /var/log/caddy/access.log
    level INFO
  }
  servers :${LISTEN_PORT} {
    protocols h1 h2 h3
  }
}

:80 {
  redir https://{host}{uri} permanent
}

:${LISTEN_PORT}, ${DOMAIN_NAME}
tls ${EMAIL_ADDRESS}
route {
  forward_proxy {
    basic_auth ${USERNAME} ${PASSWORD}
    hide_ip
    hide_via
    probe_resistance bing.com
  }
  file_server {
    root /var/www/html
  }
}
EOF


# 运行 Docker 容器 (使用用户输入的端口)
docker run --network host --name naiveproxy -v /etc/naiveproxy:/etc/naiveproxy -v /var/www/html:/var/www/html -v /var/log/caddy:/var/log/caddy -e PATH=/etc/naiveproxy/Caddyfile --restart=always -d pocat/naiveproxy