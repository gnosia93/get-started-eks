#!/bin/bash
echo "Checking for package manager lock..."
while fuser /var/lib/dnf/metadata_lock.pid /var/run/dnf.pid >/dev/null 2>&1; do
  echo "Waiting for other package manager to finish..."
  sleep 5
done

dnf clean all
dnf install -y nginx python3 python3-pip
pip3 install flask gunicorn

cat << 'EOF' > /home/ec2-user/app.py
from flask import Flask, render_template_string  
import random
import socket
import platform
import subprocess
import requests

app = Flask(__name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>EC2 Status</title>
    <link href="https://cdn.jsdelivr.net" rel="stylesheet">
    <style>
        body { background-color: #f8f9fa; padding-top: 50px; }
        .container { max-width: 800px; background: white; padding: 30px; border-radius: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .table th { width: 30%; background-color: #e9ecef; }
        .header-title { color: #0d6efd; margin-bottom: 25px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h2 class="header-title text-center">🚀 Instance Metadata & Pi Result</h2>
        <table class="table table-bordered">
            <tbody>
                {% for key, value in data.items() %}
                <tr>
                    <th>{{ key.replace('_', ' ').title() }}</th>
                    <td>{{ value }}</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        <div class="text-center mt-4">
            <button class="btn btn-primary" onclick="location.reload()">Recalculate</button>
        </div>
    </div>
</body>
</html>
"""

def get_metadata(path):
    token_url = "http://169.254.169.254/latest/api/token"
    token = requests.put(token_url, headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"}).text
    url = f"http://169.254.169.254/latest/meta-data/{path}"
    return requests.get(url, headers={"X-aws-ec2-metadata-token": token}).text

@app.route('/')
def simulate():
    n = 500000
    hits = sum(1 for _ in range(n) if random.random()**2 + random.random()**2 <= 1.0)
    
    result_data = {
        "instance_name": get_metadata("tags/instance/Name"),
        "instance_id": get_metadata("instance-id"),
        "instance_type": get_metadata("instance-type"),
        "private_ip": get_metadata("local-ipv4"),
        "hostname": socket.gethostname(),
        "architecture": platform.machine(),
        "cpu_info": subprocess.getoutput("lscpu | grep 'Model name' | cut -d: -f2").strip(),
        "pi_estimate": 4.0 * hits / n
    }

    return render_template_string(HTML_TEMPLATE, data=result_data)

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
