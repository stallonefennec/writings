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
DOMAIN="fennec-lucky.com"
EMAIL="stalloneiv@gmail.com"
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

# 更新 apt 仓库
update_apt() {
  log "更新 apt 仓库..."
  apt-get clean
  apt update
  if [[ $? -ne 0 ]]; then
    log "更新 apt 仓库失败，请检查网络和软件源配置。"
    return 1
  fi
}

# 获取 VPS 的公网 IP
get_vps_ip() {
  log "获取 VPS 公网 IP..."
  VPS_IP=$(curl -s ifconfig.me)
  if [[ -z "$VPS_IP" ]]; then
    log "获取 VPS 公网 IP 失败，请检查网络连接。"
    return 1
  else
    log "VPS 公网 IP: $VPS_IP"
  fi
}

# 获取域名和邮箱信息
ask_for_domain_email() {
    read -r -p "请输入你的域名 (默认为 fennec-lucky.com): " DOMAIN_INPUT
    DOMAIN="${DOMAIN_INPUT:-$DOMAIN}"
    log "使用的域名: $DOMAIN"

    read -r -p "请输入你的邮箱地址 (默认为 stalloneiv@gmail.com): " EMAIL_INPUT
    EMAIL="${EMAIL_INPUT:-$EMAIL}"
    log "使用的邮箱: $EMAIL"
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
    return 0
  fi
  read -r -p "是否安装 Git? (y/N): " INSTALL_GIT_ANSWER
  if [[ "$INSTALL_GIT_ANSWER" == "y" || "$INSTALL_GIT_ANSWER" == "Y" ]]; then
    log "开始安装 Git..."
    if update_apt; then
      apt install -y git
      if [[ $? -eq 0 ]]; then
        log "Git 安装完成."
        return 0
      else
        log "Git 安装失败。"
        return 1
      fi
    else
      return 1
    fi
  else
    log "跳过安装 Git."
    return 0
  fi
}

# 安装 Docker
install_docker() {
  if command -v docker &>/dev/null && command -v docker-compose &>/dev/null; then
    log "Docker 和 Docker Compose 已安装."
    return 0
  fi

  read -r -p "是否安装 Docker 和 Docker Compose? (y/N): " INSTALL_DOCKER_ANSWER
  if [[ "$INSTALL_DOCKER_ANSWER" == "y" || "$INSTALL_DOCKER_ANSWER" == "Y" ]]; then
    log "开始安装 Docker..."

    if update_apt; then
      apt install -y docker.io
      if [[ $? -ne 0 ]]; then
        log "Docker 安装失败。"
        return 1
      fi

      log "安装 Docker Compose..."
      sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      if [[ $? -ne 0 ]]; then
        log "Docker Compose 安装失败。"
        return 1
      fi

      log "Docker 和 Docker Compose 安装完成."
      return 0
    else
      return 1 # apt update 失败
    fi
  else
    log "跳过安装 Docker."
    return 0
  fi
}

# 安装 Nginx
install_nginx() {
  if command -v nginx &>/dev/null; then
    log "Nginx 已安装."
    return 0
  fi
  read -r -p "是否安装 Nginx? (y/N): " INSTALL_NGINX_ANSWER
  if [[ "$INSTALL_NGINX_ANSWER" == "y" || "$INSTALL_NGINX_ANSWER" == "Y" ]]; then
    log "开始安装 Nginx..."
    if update_apt; then
      apt install -y nginx
      if [[ $? -eq 0 ]]; then
        log "Nginx 安装完成."
        if systemctl is-active nginx; then
          log "Nginx 服务正在运行."
        else
          log "Nginx 服务未运行，尝试启动..."
          systemctl start nginx
          if systemctl is-active nginx; then
            log "Nginx 服务启动成功."
            return 0
          else
            log "Nginx 服务启动失败，请检查日志。"
            return 1
          fi
        fi
        return 0
      else
        log "Nginx 安装失败。"
        return 1
      fi
    else
      return 1
    fi
  else
    log "跳过安装 Nginx."
    return 0
  fi
}

# 配置 HTTPS 证书 (Let's Encrypt)
configure_https() {
  read -r -p "是否配置 HTTPS 证书 (Let's Encrypt)? (y/N): " LETSENCRYPT_ANSWER
  if [[ "$LETSENCRYPT_ANSWER" == "y" || "$LETSENCRYPT_ANSWER" == "Y" ]]; then
    if check_domain_dns; then
      log "开始配置 HTTPS 证书..."
      if update_apt; then
        apt install -y certbot python3-certbot-nginx
        if [[ $? -ne 0 ]]; then
          log "安装 certbot 失败。"
          return 1
        fi
        certbot --nginx --agree-tos --no-eff-email -m "$EMAIL" -d "$DOMAIN"
        if [[ $? -eq 0 ]]; then
          log "HTTPS 证书配置完成."
          return 0
        else
          log "HTTPS 证书配置失败。"
          return 1
        fi
      else
        return 1
      fi
    else
      log "域名解析未指向当前服务器IP，跳过HTTPS证书配置"
      return 0
    fi
  else
    log "跳过 HTTPS 证书配置."
    return 0
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
    if [[ $? -ne 0 ]]; then
      log "Nginx 反向代理配置失败, 请检查 nginx 日志。"
      return 1
    fi
  log "Nginx 反向代理配置完成."
  return 0
}

# 创建 docker-compose.yml 文件
create_docker_compose() {
  log "创建 docker-compose.yml 文件..."
  cat << EOF > docker-compose.yml
services:
  memos:
    image: ghcr.io/usememos/memos:latest
    container_name: memos
    ports:
      - "127.0.0.1:${CONTAINER_PORT}:${CONTAINER_PORT}"
    volumes:
      - ~/.memos:/var/opt/memos
    restart: always
EOF
  log "docker-compose.yml 文件已创建."
}

# 启动 Memos
start_memos() {
  log "启动 Memos..."
  if [ ! -d "~/.memos" ]; then
    mkdir ~/.memos
  fi
    docker-compose up -d
    if [[ $? -ne 0 ]]; then
      log "Memos 启动失败, 请检查 docker 日志。"
      return 1
    fi
  log "Memos 已启动，可通过 https://$DOMAIN 访问."
  
 
}

# 主流程
get_vps_ip
ask_for_domain_email

# 集中更新 apt 仓库
update_apt

if install_git; then
  log "Git 安装或已存在."
fi

if install_docker; then
  log "Docker 安装或已存在."
  create_docker_compose
fi

if install_nginx; then
  log "Nginx 安装或已存在."
  if check_domain_dns; then
     configure_https
    if configure_nginx_proxy; then
      if install_docker; then # 在配置好 nginx 之后再启动 memos
        start_memos
        fi
      fi
  fi
fi
systemctl restart nginx
log "nginx 已刷新"

log "脚本执行完毕."