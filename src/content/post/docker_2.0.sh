#!/bin/bash

# 确保脚本以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo "该脚本需要root权限，请使用sudo命令运行" 1>&2
   exit 1
fi

# 定义变量
INSTALL_DOCKER=false
INSTALL_NGINX=false
INSTALL_COMPOSE=false
CERT_APPLIED=false # 添加一个变量来记录证书是否成功申请

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

# 检测 Nginx 是否已安装
if command -v nginx &> /dev/null; then
  echo "Nginx已安装."
else
    read -p "Nginx 未安装，是否要安装？ (y/n): " install_nginx_choice
    if [[ "$install_nginx_choice" == "y" || "$install_nginx_choice" == "Y" ]]; then
        INSTALL_NGINX=true
    else
        echo "Nginx 未安装，脚本将继续运行，请确保 Nginx 已经安装好."
    fi
fi

# 安装Nginx (如果需要)
if [ "$INSTALL_NGINX" = true ]; then
  echo "正在安装Nginx..."
  apt update
  apt install -y nginx
fi


# 自动申请证书(在安装Nginx之后)
if [ "$INSTALL_NGINX" = true ]; then
  echo "正在使用 certbot 获取证书..."
  apt install -y certbot python3-certbot-nginx
  if ! certbot --nginx --non-interactive --agree-tos --email ${EMAIL_ADDRESS} -d ${DOMAIN_NAME}; then
      echo "证书申请失败，请检查您的域名和 DNS 解析是否正确。"
      exit 1
  else
    CERT_APPLIED=true
   fi
fi


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

# 安装Docker (如果需要)
if [ "$INSTALL_DOCKER" = true ]; then
    echo "正在安装Docker..."
    apt update
    apt install -y docker.io
fi

# 安装Docker Compose Plugin (如果需要)
if [ "$INSTALL_COMPOSE" = true ]; then
  echo "正在安装Docker Compose plugin..."
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
fi

echo "Docker安装完成。"

# 检测 naiveproxy 是否已经在运行
if docker ps -q -f "name=naiveproxy" | grep -q . ; then
    echo "naiveproxy 容器已经在运行，正在停止或者删除该容器!"
    docker stop naiveproxy
    docker rm naiveproxy
    exit 1
fi

# 创建目录
mkdir -p /etc/naiveproxy /var/www/html /var/log/nginx

# 生成 Nginx 配置文件 (只有在证书申请成功后才执行)
if [ "$CERT_APPLIED" = true ]; then
 cat > /etc/nginx/conf.d/naiveproxy.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # mozilla ssl config
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    location / {
        proxy_pass http://127.0.0.1:${LISTEN_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        # WebSocket settings
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
fi

# 创建 docker-compose.yml 文件 (动态生成，只包含 naiveproxy)
cat > docker-compose.yml <<EOF
services:
  naiveproxy:
    image: pocat/naiveproxy
    container_name: naiveproxy
    network_mode: "host"
    volumes:
      - /etc/naiveproxy:/etc/naiveproxy
      - /var/www/html:/var/www/html
    environment:
      - PATH=/etc/naiveproxy/Caddyfile
      - LISTEN_PORT=${LISTEN_PORT} # 使用 LISTEN_PORT
    restart: always
EOF

# 启动 Docker Compose
echo "正在使用 Docker Compose 启动 naiveproxy 服务..."
docker-compose up -d


# 启动 Nginx
if [ "$INSTALL_NGINX" = true ] && [ "$CERT_APPLIED" = true ]; then
    echo "正在启动 Nginx 服务..."
    systemctl enable nginx
    systemctl restart nginx

  # 测试nginx配置
   if ! nginx -t; then
       echo "nginx配置错误，请检查配置文件"
       exit 1
   fi
fi

echo "naiveproxy 服务已启动."