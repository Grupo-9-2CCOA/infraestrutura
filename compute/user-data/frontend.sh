#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx

cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html lang="pt-BR">
  <head><meta charset="utf-8"><title>${frontend_name}</title></head>
  <body>
    <h1>${frontend_name}</h1>
    <p>Backend pareado: ${backend_private_ip}:${backend_port}</p>
  </body>
</html>
HTML

cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen ${frontend_port} default_server;
    listen [::]:${frontend_port} default_server;

    root /var/www/html;
    index index.html;

    location = /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'healthy';
    }

    location /api/ {
        proxy_pass http://${backend_private_ip}:${backend_port}/;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

nginx -t
systemctl enable --now nginx
