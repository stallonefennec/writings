#!/bin/bash
# 该脚本将自动更新软件包列表并安装Docker

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

echo "Docker安装完成。"
# Pull the Docker image
docker pull pocat/naiveproxy

# Create directories
mkdir -p /etc/naiveproxy /var/www/html /var/log/caddy

# Create Caddyfile
cat > /etc/naiveproxy/Caddyfile <<EOF
{
 admin off
 log {
   output file /var/log/caddy/access.log
   level INFO
 }
 servers :48658 {
   protocols h1 h2 h3
 }
}

:80 {
 redir https://{host}{uri} permanent
}

:48658, fennec-lucky.com
tls stalloneiv@gmail.com
route {
 forward_proxy {
   basic_auth stallone 198964
   hide_ip
   hide_via
   probe_resistance bing.com
 }
 file_server {
   root /var/www/html
 }
}
EOF

# Run the Docker container
docker run --network host --name naiveproxy -v /etc/naiveproxy:/etc/naiveproxy -v /var/www/html:/var/www/html -v /var/log/caddy:/var/log/caddy -e PATH=/etc/naiveproxy/Caddyfile --restart=always -d pocat/naiveproxy