#!/bin/bash

# 检查是否是 root 用户
if [[ "$EUID" -ne 0 ]]; then
  echo "请以 root 用户身份运行此脚本。"
  exit 1
fi

# 定义日志文件路径
LOG_FILE="/var/log/setup_memos.log"
# 清空日志文件
> "$LOG_FILE"

# 定义全局变量
DOMAIN=""
EMAIL=""
INSTALL_GIT=false
INSTALL_DOCKER=false
INSTALL_NGINX=false
LETSENCRYPT=false
VPS_IP=""
CONTAINER_PORT=5230

# 定义日志函数
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 获取 VPS 的公网 IP
get_vps_ip() {
  log "获取 VPS 公网 IP..."
  VPS_IP=$(curl -s ifconfig.me)
  if [[ -z "$VPS_IP" ]]; then
    log "获取 VPS 公网 IP 失败，请检查网络连接。"
    exit 1
  else
    log "VPS 公网 IP: $VPS_IP"
  fi
}

# 获取域名和邮箱信息
ask_for_domain_email() {
  while [[ -z "$DOMAIN" ]]; do
    read -r -p "请输入你的域名 (例如: example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
      log "域名不能为空，请重新输入。"
    fi
  done

  while [[ -z "$EMAIL" ]]; do
    read -r -p "请输入你的邮箱地址 (用于 Let's Encrypt 证书): " EMAIL
    if [[ -z "$EMAIL" ]]; then
      log "邮箱地址不能为空，请重新输入。"
    fi
  done
}

# 检查域名是否指向 VPS IP
check_domain_dns() {
  log "正在检查域名 $DOMAIN 是否指向 VPS IP $VPS_IP ..."
  DOMAIN_IP=$(dig +short "$DOMAIN" A)
  if [[ -z "$DOMAIN_IP" ]]; then
    log "无法解析域名 $DOMAIN，请检查域名解析是否正确。"
    return 1
  elif [[ "$DOMAIN_IP" != "$VPS_IP" ]]; then
    log "域名 $DOMAIN 解析的 IP 地址 ($DOMAIN_IP) 与 VPS IP ($VPS_IP) 不匹配，请检查域名解析。"
    return 1
  else
    log "域名 $DOMAIN 指向 VPS IP $VPS_IP，域名解析正确。"
    return 0
  fi
}

# 安装 Git
install_git() {
  if command -v git &>/dev/null; then
    log "Git 已安装."
  else
    read -r -p "是否安装 Git? (y/N): " INSTALL_GIT_ANSWER
    if [[ "$INSTALL_GIT_ANSWER" == "y" || "$INSTALL_GIT_ANSWER" == "Y" ]]; then
      log "开始安装 Git..."
      apt update && apt install -y git
      if [[ $? -eq 0 ]]; then
        log "Git 安装完成."
      else
        log "Git 安装失败."
         return 1
      fi
    else
      log "跳过安装 Git."
    fi
  fi
}

# 安装 Docker
install_docker() {
  if command -v docker &>/dev/null && command -v docker-compose &>/dev/null; then
    log "Docker 和 Docker Compose 已安装."
  else
    read -r -p "是否安装 Docker 和 Docker Compose? (y/N): " INSTALL_DOCKER_ANSWER
    if [[ "$INSTALL_DOCKER_ANSWER" == "y" || "$INSTALL_DOCKER_ANSWER" == "Y" ]]; then
      log "开始安装 Docker..."
      apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt update && apt install -y docker-ce docker-ce-cli containerd.io
      if [[ $? -eq 0 ]]; then
        log "Docker 安装完成."
        # Docker Compose 安装 (使用 pip)
        if ! command -v docker compose &>/dev/null; then
          log "开始安装 Docker Compose (使用 pip)..."
          apt install -y python3-pip
          pip3 install docker-compose
          if [[ $? -eq 0 ]]; then
            log "Docker Compose 安装完成."
          else
            log "Docker Compose 安装失败."
             return 1
          fi
         else
          log "Docker Compose 已安装."
        fi
      else
        log "Docker 安装失败."
         return 1
      fi
    else
      log "跳过安装 Docker."
    fi
  fi
}

# 安装 Nginx
install_nginx() {
  if command -v nginx &>/dev/null; then
    log "Nginx 已安装."
  else
    read -r -p "是否安装 Nginx? (y/N): " INSTALL_NGINX_ANSWER
    if [[ "$INSTALL_NGINX_ANSWER" == "y" || "$INSTALL_NGINX_ANSWER" == "Y" ]]; then
      log "开始安装 Nginx..."
      apt update && apt install -y nginx
      if [[ $? -eq 0 ]]; then
        log "Nginx 安装完成."
          # 检查 Nginx 服务是否启动
        if systemctl is-active nginx; then
          log "Nginx 服务正在运行."
        else
          log "Nginx 服务未运行，尝试启动..."
          systemctl start nginx
          if systemctl is-active nginx; then
            log "Nginx 服务启动成功."
          else
            log "Nginx 服务启动失败，请检查日志。"
             return 1
          fi
        fi
      else
        log "Nginx 安装失败."
         return 1
      fi
    else
      log "跳过安装 Nginx."
    fi
  fi
}

# 配置 HTTPS 证书 (Let's Encrypt)
configure_https() {
  read -r -p "是否配置 HTTPS 证书 (Let's Encrypt)? (y/N): " LETSENCRYPT_ANSWER
  if [[ "$LETSENCRYPT_ANSWER" == "y" || "$LETSENCRYPT_ANSWER" == "Y" ]]; then
    if check_domain_dns; then
      log "开始配置 HTTPS 证书..."
      apt update
      apt install -y certbot python3-certbot-nginx
      certbot --nginx --agree-tos --no-eff-email -m "$EMAIL" -d "$DOMAIN"
      if [[ $? -eq 0 ]]; then
        log "HTTPS 证书配置完成."
      else
        log "HTTPS 证书配置失败."
        return 1
      fi
    else
      log "域名解析未指向当前服务器IP，跳过HTTPS证书配置"
      return 1
    fi
  else
    log "跳过 HTTPS 证书配置."
  fi
}

# 配置 Nginx 反向代理
configure_nginx_proxy() {
  log "配置 Nginx 反向代理..."
  NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
  cat << EOF > "$NGINX_CONFIG"
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:$CONTAINER_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
  ln -s "$NGINX_CONFIG" "/etc/nginx/sites-enabled/"
  rm -f "/etc/nginx/sites-enabled/default"
  systemctl restart nginx
  log "Nginx 反向代理配置完成."
}

# 创建 docker-compose.yml 文件
create_docker_compose() {
    cat << EOF > docker-compose.yml
version: "3.8"
services:
  memos:
    image: ghcr.io/usememos/memos:latest
    container_name: memos
    ports:
      - "127.0.0.1:${CONTAINER_PORT}:${CONTAINER_PORT}"
    volumes:
      - ./memos_data:/var/opt/memos
    restart: always
EOF
    log "docker-compose.yml 文件已创建."
}

# 启动 Memos
start_memos() {
  if [ ! -d "memos_data" ]; then
    mkdir memos_data
  fi
  docker compose up -d
  log "Memos 已启动，可通过 https://$DOMAIN:${CONTAINER_PORT} 访问."
}

# 主流程
get_vps_ip
ask_for_domain_email
install_git
install_docker
install_nginx
configure_https
configure_nginx_proxy
create_docker_compose
start_memos

log "脚本执行完毕."