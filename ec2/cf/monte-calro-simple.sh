#!/bin/bash

dnf clean all && dnf install -y nginx python3 python3-pip
pip3 install flask gunicorn

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
ExecStart=/bin/sh -c '/usr/local/bin/gunicorn --workers $(( $(nproc) * 2 )) --bind 127.0.0.1:8080 app:app'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nginx flask-api
systemctl start nginx flask-api

while fuser /var/lib/dnf/metadata_lock >/dev/null 2>&1; do
    echo "Waiting for other package manager to finish..."
    sleep 3
done

dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

docker run -d --name node_exporter --restart always --net="host" --pid="host" -v "/:/host:ro,rslave" \
  prom/node-exporter:latest --path.rootfs=/host

sleep 5
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INST_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
HASH_VAL=$(echo $INST_ID | tail -c 5)
aws ec2 create-tags --resources $INST_ID --tags Key=Name,Value="$(uname -m)-nginx-$HASH_VAL" --region "$REGION"
