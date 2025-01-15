#!/bin/bash

# 确保脚本以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo "该脚本需要root权限，请使用sudo命令运行" 1>&2
   exit 1
fi

# 检测是否安装 docker
if ! command -v docker &> /dev/null
then
    echo "Docker 没有安装，是否要安装？ [y/N]"
    read -r install_docker
    if [[ $install_docker =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "正在更新软件包列表..."
        apt update
        echo "正在安装 Docker..."
        apt install -y docker.io
        echo "Docker 安装完成。"
    else
      echo "Docker 没有安装，请手动安装"
      exit 1
    fi
fi

# 检测是否安装 docker compose
if ! command -v docker-compose &> /dev/null
then
  echo "Docker Compose 没有安装，是否要安装？ [y/N]"
  read -r install_docker_compose
  if [[ $install_docker_compose =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo "正在安装 Docker Compose..."
      apt install -y docker-compose
      echo "Docker Compose 安装完成。"
    else
      echo "Docker Compose 没有安装，请手动安装"
       exit 1
  fi
fi

# 设置默认值
default_domain="fennec-lucky.com"
default_port="48658"
default_email="stalloneiv@gmail.com"
default_username="stallone"
default_password="198964"

# 询问是否更改域名
echo "是否更改域名？ (默认: $default_domain) [y/N]"
read -r change_domain
if [[ $change_domain =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "请输入新的域名："
  read -r new_domain
  domain="$new_domain"
else
  domain="$default_domain"
fi

# 询问是否更改端口
echo "是否更改端口？ (默认: $default_port) [y/N]"
read -r change_port
if [[ $change_port =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "请输入新的端口："
  read -r new_port
    port="$new_port"
else
   port="$default_port"
fi

# 询问是否更改邮箱
echo "是否更改邮箱？ (默认: $default_email) [y/N]"
read -r change_email
if [[ $change_email =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "请输入新的邮箱地址："
  read -r new_email
  email="$new_email"
else
  email="$default_email"
fi

# 询问是否更改用户名
echo "是否更改用户名？ (默认: $default_username) [y/N]"
read -r change_username
if [[ $change_username =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "请输入新的用户名："
  read -r new_username
  username="$new_username"
else
  username="$default_username"
fi

# 询问是否更改密码
echo "是否更改密码？ (默认: $default_password) [y/N]"
read -r change_password
if [[ $change_password =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "请输入新的密码："
  read -r new_password
  password="$new_password"
else
   password="$default_password"
fi

# 创建目录
mkdir -p naiveproxy html caddy_logs

# 创建 Caddyfile
cat > naiveproxy/Caddyfile <<EOF
{
 admin off
 log {
   output file /var/log/caddy/access.log
   level INFO
 }
 servers :$port {
   protocols h1 h2 h3
 }
}

:80 {
 redir https://{host}{uri} permanent
}

:$port, $domain
tls $email
route {
 forward_proxy {
   basic_auth $username $password
   hide_ip
   hide_via
   probe_resistance bing.com
 }
 file_server {
   root /var/www/html
 }
}
EOF

# 创建 docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  naiveproxy:
    image: pocat/naiveproxy
    container_name: naiveproxy
    restart: always
    network_mode: host
    volumes:
      - ./naiveproxy:/etc/naiveproxy
      - ./html:/var/www/html
      - ./caddy_logs:/var/log/caddy
    environment:
      - PATH=/etc/naiveproxy/Caddyfile
    command: /bin/sh -c "caddy run --config /etc/naiveproxy/Caddyfile"
EOF
docker-compose up -d
echo "已经使用docker-compose up -d 命令启动服务"