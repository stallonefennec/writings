#!/bin/bash

# 检查是否是 root 用户
if [[ "$EUID" -ne 0 ]]; then
  echo "请以 root 用户身份运行此脚本。"
  exit 1
fi

# 定义全局变量
DOMAIN=""
EMAIL=""
INSTALL_GIT=false
INSTALL_DOCKER=false
INSTALL_COMPOSE=false
INSTALL_NGINX=false
LETSENCRYPT=false

# 获取域名和邮箱信息
ask_for_domain_email() {
  while [[ -z "$DOMAIN" ]]; do
    read -r -p "请输入你的域名 (例如: example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
      echo "域名不能为空，请重新输入。"
    fi
  done

  while [[ -z "$EMAIL" ]]; do
    read -r -p "请输入你的邮箱地址 (用于 Let's Encrypt 证书): " EMAIL
    if [[ -z "$EMAIL" ]]; then
      echo "邮箱地址不能为空，请重新输入。"
    fi
  done
}


# 检查是否安装 git 并提示安装
check_and_install_git() {
  if command -v git &>/dev/null; then
    echo "Git 已安装."
  else
    read -r -p "是否安装 Git? (y/N): " INSTALL_GIT_ANSWER
    if [[ "$INSTALL_GIT_ANSWER" == "y" || "$INSTALL_GIT_ANSWER" == "Y" ]]; then
      echo "开始安装 Git..."
      apt update && apt install -y git
      if [[ $? -eq 0 ]]; then
        echo "Git 安装完成."
      else
        echo "Git 安装失败."
      fi
    else
      echo "跳过安装 Git."
    fi
  fi
}

# 检查是否安装 Docker 并提示安装
check_and_install_docker() {
  if command -v docker &>/dev/null; then
    echo "Docker 已安装."
  else
    read -r -p "是否安装 Docker? (y/N): " INSTALL_DOCKER_ANSWER
    if [[ "$INSTALL_DOCKER_ANSWER" == "y" || "$INSTALL_DOCKER_ANSWER" == "Y" ]]; then
      echo "开始安装 Docker..."
      apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt update && apt install -y docker-ce docker-ce-cli containerd.io
      if [[ $? -eq 0 ]]; then
        echo "Docker 安装完成."
      else
        echo "Docker 安装失败."
      fi
    else
      echo "跳过安装 Docker."
    fi
  fi
}

# 检查是否安装 docker compose plugin 并提示安装
check_and_install_compose() {
    if command -v docker compose &>/dev/null; then
        echo "Docker Compose plugin 已安装."
    else
        read -r -p "是否安装 Docker Compose Plugin? (y/N): " INSTALL_COMPOSE_ANSWER
        if [[ "$INSTALL_COMPOSE_ANSWER" == "y" || "$INSTALL_COMPOSE_ANSWER" == "Y" ]]; then
            echo "开始安装 Docker Compose plugin..."
            apt update && apt install -y docker-compose-plugin
            if [[ $? -eq 0 ]]; then
                echo "Docker Compose plugin 安装完成."
            else
                echo "Docker Compose plugin 安装失败."
            fi
        else
            echo "跳过安装 Docker Compose plugin."
        fi
    fi
}

# 检查是否安装 Nginx 并提示安装
check_and_install_nginx() {
  if command -v nginx &>/dev/null; then
    echo "Nginx 已安装."
  else
    read -r -p "是否安装 Nginx? (y/N): " INSTALL_NGINX_ANSWER
    if [[ "$INSTALL_NGINX_ANSWER" == "y" || "$INSTALL_NGINX_ANSWER" == "Y" ]]; then
      echo "开始安装 Nginx..."
      apt update && apt install -y nginx
      if [[ $? -eq 0 ]]; then
        echo "Nginx 安装完成."
      else
        echo "Nginx 安装失败."
      fi
    else
      echo "跳过安装 Nginx."
    fi
  fi
}

# 配置 HTTPS 证书 (Let's Encrypt)
configure_https() {
  read -r -p "是否配置 HTTPS 证书 (Let's Encrypt)? (y/N): " LETSENCRYPT_ANSWER
    if [[ "$LETSENCRYPT_ANSWER" == "y" || "$LETSENCRYPT_ANSWER" == "Y" ]]; then
        echo "开始配置 HTTPS 证书..."
        apt update
        apt install -y certbot python3-certbot-nginx
        certbot --nginx --agree-tos --no-eff-email -m "$EMAIL" -d "$DOMAIN"
        if [[ $? -eq 0 ]]; then
            echo "HTTPS 证书配置完成."
        else
            echo "HTTPS 证书配置失败."
        fi
    else
        echo "跳过 HTTPS 证书配置."
    fi
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
      - "5230:5230"
    volumes:
      - ~/.memos:/var/opt/memos
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.memos.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.memos.entrypoints=websecure"
      - "traefik.http.routers.memos.tls=true"

networks:
    default:
        external: true
        name: traefik_webgateway
EOF
  echo "docker-compose.yml 文件已创建."
}


# 启动 Memos
start_memos() {
    if [ ! -d "memos_data" ]; then
        mkdir memos_data
    fi
    docker compose up -d
    echo "Memos 已启动，可通过 https://$DOMAIN 访问."
}


# 主流程
ask_for_domain_email
check_and_install_git
check_and_install_docker
check_and_install_compose
check_and_install_nginx
configure_https
create_docker_compose
start_memos

echo "脚本执行完毕."