#!/bin/bash

# 确保脚本以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo "该脚本需要root权限，请使用sudo命令运行" 1>&2
   exit 1
fi

# 定义变量
INSTALL_DOCKER=false
INSTALL_CADDY=false
INSTALL_COMPOSE=false # 新增变量

# 检测Docker是否已安装
if command -v docker &> /dev/null; then
    echo "Docker已安装."
else
    read -p "Docker未安装，是否要安装？ (y/n): " install_docker_choice
    if [[ "$install_docker_choice" == "y" || "$install_docker_choice" == "Y" ]]; then
        INSTALL_DOCKER=true
    else
      echo "Docker未安装，脚本退出."
      exit 1
    fi
fi


# 检测Docker Compose是否已安装
if command -v docker-compose &> /dev/null; then
    echo "Docker Compose已安装."
else
  read -p "Docker Compose未安装，是否要安装？ (y/n): " install_compose_choice
    if [[ "$install_compose_choice" == "y" || "$install_compose_choice" == "Y" ]]; then
        INSTALL_COMPOSE=true
    else
      echo "Docker Compose未安装，脚本退出."
      exit 1
    fi
fi


# 检测 Caddy 是否已安装 (这里假设你使用 apt 安装的，实际安装方式不同，检测方式需要调整)
if command -v caddy &> /dev/null; then
   echo "Caddy 已安装."
else
    read -p "Caddy 未安装，是否要安装？ (y/n): " install_caddy_choice
    if [[ "$install_caddy_choice" == "y" || "$install_caddy_choice" == "Y" ]]; then
        INSTALL_CADDY=true
    else
        echo "Caddy 未安装，脚本将继续运行，请确保 Caddy 已经安装好."
    fi
fi


# 安装Docker (如果需要)
if [ "$INSTALL_DOCKER" = true ]; then
    echo "正在安装Docker..."
    apt update
    apt install -y docker.io
fi

# 安装Docker Compose (如果需要)
if [ "$INSTALL_COMPOSE" = true ]; then
  echo "正在安装Docker Compose plugin..."
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
fi

# 安装Caddy (如果需要)
if [ "$INSTALL_CADDY" = true ]; then
  echo "正在安装 Caddy..."
  apt update
  apt install -y caddy
fi


echo "Docker安装完成。"

# 检测 naiveproxy 是否已经在运行
if docker ps -q -f "name=naiveproxy" | grep -q . ; then
    echo "naiveproxy 容器已经在运行，请先停止或者删除该容器!"
    exit 1
fi


# 创建目录
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

# 创建 docker-compose.yml 文件 (动态生成，只包含 naiveproxy)
cat > docker-compose.yml <<EOF
version: "3.9"
services:
  naiveproxy:
    image: pocat/naiveproxy
    container_name: naiveproxy
    network_mode: "host"
    volumes:
      - /etc/naiveproxy:/etc/naiveproxy
      - /var/www/html:/var/www/html
      - /var/log/caddy:/var/log/caddy
    environment:
      - PATH=/etc/naiveproxy/Caddyfile
    restart: always
EOF

# 启动 Docker Compose
echo "正在使用 Docker Compose 启动 naiveproxy 服务..."
docker-compose up -d

echo "naiveproxy 服务已启动."