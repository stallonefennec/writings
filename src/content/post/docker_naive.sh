#!/bin/bash

sudo apt update
sudo apt install docker.io
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
