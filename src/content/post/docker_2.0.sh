#!/bin/bash
# 该脚本将自动更新软件包列表并安装Docker，并允许用户输入端口和域名

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

# 获取用户输入
read -p "请输入监听端口 (例如: 48658): " LISTEN_PORT
read -p "请输入域名 (例如: fennec-lucky.com): " DOMAIN_NAME
read -p "请输入邮箱地址 (用于获取TLS证书): " EMAIL_ADDRESS
read -p "请输入用户名 (用于基本身份验证): " USERNAME
read -p "请输入密码 (用于基本身份验证): " PASSWORD

# 创建 Caddyfile (使用用户输入)
cat > /etc/naiveproxy/Caddyfile <<EOF
{
  admin off
  log {
    output file /var/log/caddy/access.log
    level INFO
  }
  servers {
    protocols h1 h2 h3
  }
}


${DOMAIN_NAME} {
  tls ${EMAIL_ADDRESS} # 使用用户输入的邮箱地址
  reverse_proxy localhost:8000 { # 假设 Marzban 监听 8000 端口
    header_up Host {host}
    header_up X-Real-IP {remote_host}
    header_up X-Forwarded-Proto {scheme}
  }
}


:80 {
  redir https://{host}{uri} permanent
}


:${LISTEN_PORT} { # 使用用户输入的端口作为代理服务器
  tls ${EMAIL_ADDRESS}
  route {
     basic_auth ${USERNAME} ${PASSWORD}
    forward_proxy {
        hide_ip
        hide_via
        probe_resistance bing.com
    }
  }
}
EOF


# 运行 Docker 容器 (使用用户输入的端口)
docker run --network host --name naiveproxy -v /etc/naiveproxy:/etc/naiveproxy -v /var/www/html:/var/www/html -v /var/log/caddy:/var/log/caddy -e PATH=/etc/naiveproxy/Caddyfile --restart=always -d pocat/naiveproxy