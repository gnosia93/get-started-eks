#!/bin/bash
set -e
echo "Checking for package manager lock..."
while fuser /var/lib/dnf/metadata_lock.pid /var/run/dnf.pid >/dev/null 2>&1; do
  echo "Waiting for other package manager to finish..."
  sleep 5
done

dnf clean all && dnf install -y nginx python3 python3-pip
pip install flask gunicorn

cat << 'EOF' > /home/ec2-user/app.py
from flask import Flask, jsonify
import random

app = Flask(__name__)

@app.route('/')
def simulate():
    n = 500000
    hits = sum(1 for _ in range(n) if random.random()**2 + random.random()**2 <= 1.0)
    return jsonify(pi_estimate=4.0 * hits / n)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
EOF

cat << 'EOF' > /etc/nginx/conf.d/proxy.conf
server {
    listen 80;
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF
rm -f /etc/nginx/conf.d/default.conf

cat << EOF > /etc/systemd/system/flask-api.service
[Unit]
Description=Gunicorn Monte Carlo API
After=network.target

[Service]
User=root
WorkingDirectory=/home/ec2-user
ExecStart=/bin/sh -c 'gunicorn --workers $(( $(nproc) * 2 )) --bind 127.0.0.1:8080 app:app'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now nginx flask-api
