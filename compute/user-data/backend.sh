#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3

cat > /etc/backend.env <<'ENV'
BACKEND_NAME=${backend_name}
MYSQL_HOST=${mysql_private_ip}
MYSQL_PORT=3306
MYSQL_DATABASE=${mysql_database}
MYSQL_USER=${mysql_user}
ENV
chmod 600 /etc/backend.env

cat > /usr/local/bin/backend.py <<'PYTHON'
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status = 200
        payload = {
            "service": os.environ.get("BACKEND_NAME"),
            "database_host": os.environ.get("MYSQL_HOST"),
            "status": "healthy",
        }
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


HTTPServer(("0.0.0.0", ${backend_port}), Handler).serve_forever()
PYTHON

cat > /etc/systemd/system/backend.service <<'SERVICE'
[Unit]
Description=Example paired backend service
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=/etc/backend.env
ExecStart=/usr/bin/python3 /usr/local/bin/backend.py
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now backend

