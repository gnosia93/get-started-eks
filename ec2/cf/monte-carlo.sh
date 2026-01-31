#!/bin/bash
# 1. 필수 패키지 설치
yum update -y
yum install -y nginx python3 python3-pip

# 2. Flask 및 Gunicorn 설치
pip3 install flask gunicorn

# 3. Flask API 앱 작성 (상세 메타데이터 포함)
cat << 'EOF' > /home/ec2-user/app.py
from flask import Flask, jsonify
import random
import socket
import platform
import subprocess
import requests

app = Flask(__name__)

def get_metadata(path):
    # IMDSv2 토큰 가져오기
    token_url = "http://169.254.169.254/latest/api/token"
    token = requests.put(token_url, headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"}).text
    # 메타데이터 요청
    url = f"http://169.254.169.254/latest/meta-data/{path}"
    return requests.get(url, headers={"X-aws-ec2-metadata-token": token}).text

@app.route('/')
def simulate():
    # 몬테카를로 시뮬레이션
    n = 100000
    hits = sum(1 for _ in range(n) if random.random()**2 + random.random()**2 <= 1.0)
    
    # 인스턴스 정보 수집
    try:
        instance_id = get_metadata("instance-id")
        instance_type = get_metadata("instance-type")
        local_ip = get_metadata("local-ipv4")
        instance_name = "monte-carlo-graviton" 
    except:
        instance_id = instance_type = local_ip = "unknown"

    return jsonify({
        "instance_name": instance_name,
        "instance_id": instance_id,
        "instance_type": instance_type,
        "private_ip": local_ip,
        "hostname": socket.gethostname(),
        "architecture": platform.machine(),
        "cpu_info": subprocess.getoutput("lscpu | grep 'Model name' | cut -d: -f2").strip(),
        "pi_estimate": 4.0 * hits / n
    })

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
EOF

# 4. Nginx Reverse Proxy 설정
cat << 'EOF' > /etc/nginx/conf.d/proxy.conf
server {
    listen 80;
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF
rm -f /etc/nginx/conf.d/default.conf

# 5. Gunicorn 서비스 등록
cat << EOF > /etc/systemd/system/flask-api.service
[Unit]
Description=Gunicorn Monte Carlo API
After=network.target

[Service]
User=root
WorkingDirectory=/home/ec2-user
ExecStart=/usr/local/bin/gunicorn --workers 3 --bind 127.0.0.1:8080 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. 서비스 시작
systemctl daemon-reload
systemctl enable nginx flask-api
systemctl start nginx flask-api
