#!/usr/bin/env bash
#
# This script is used to install the Ghost blog on Fedora. It works using the
# Digitalocean Fedora 24 droplet. The ghost service runs as the 'ghost' user
# and is rooted at /var/www/ghost. Run the script and configure ghost.
#
# Restart the ghost service (I create a systemd file): systemctl restart ghost
#

set -ex

dnf install -y python gcc gcc-c++ make automake
dnf install -y nginx nodejs npm unzip

GHOST_ROOT=/var/www/ghost
GHOST_GROUP=ghost
GHOST_USER=ghost
GHOST_VERSION=0.11.3

groupadd ${GHOST_GROUP}
useradd -s /bin/false -g ${GHOST_GROUP} ${GHOST_USER}

mkdir -p ${GHOST_ROOT}

pushd ${GHOST_ROOT}
  curl -L https://github.com/TryGhost/Ghost/releases/download/${GHOST_VERSION}/Ghost-${GHOST_VERSION}.zip -o ../ghost.zip
  unzip ../ghost.zip -d .
  chown -R ${GHOST_USER}:${GHOST_GROUP} ${GHOST_ROOT}
popd

# IMPORTANT NOTE:
# The --verbose is needed here! Otherwise npm will fail for unknown reasons.
sudo -H -u ghost /bin/bash -c "cd ${GHOST_ROOT} && npm --verbose install --production"

cat > /etc/systemd/system/ghost.service << EOL
[Unit]
Description=ghost
After=network.target

[Service]
Type=simple
WorkingDirectory=${GHOST_ROOT}
User=${GHOST_USER}
Group=${GHOST_GROUP}
ExecStart=/usr/bin/npm start --production
ExecStop=/usr/bin/npm stop --production
Restart=always
SyslogIdentifier=Ghost

[Install]
WantedBy=multi-user.target
EOL


cat > /etc/nginx/conf.d/ljdelight.com.conf << EOL
server {
    listen 80 default_server;
    # listen [::]:80 default_server ipv6only=on;
    # listen 443 default_server ssl;
    # listen [::]:443 default_server ipv6only=on ssl;

    server_name ljdelight.com;
    client_max_body_size 2G;

    # ssl_certificate /etc/nginx/ssl/ljdelightcom.crt;
    # ssl_certificate_key /etc/nginx/ssl/ljdelightcom.pem;

    location / {
        proxy_pass http://localhost:2368;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
EOL


cat > /etc/nginx/nginx.conf << EOL
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    include /etc/nginx/conf.d/*.conf;
    gzip on;
    gzip_disable "msie6";
    # ssl_protocols TLSv1.1 TLSv1.2;
    # ssl_ciphers "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK";
    # ssl_dhparam /etc/ssl/certs/dhparam.pem;
    # ssl_prefer_server_ciphers on;
    # ssl_session_cache shared:SSL:10m;
}
EOL


systemctl daemon-reload
systemctl restart ghost nginx
systemctl enable ghost nginx

echo "Disable selinux!"
echo "Configure ghost at /var/www/ghost"
