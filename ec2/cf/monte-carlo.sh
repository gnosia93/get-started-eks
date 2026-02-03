#!/bin/bash
# 1. dnf/yum 프로세스 대기 로직 (충돌 방지)
echo "Checking for package manager lock..."
while fuser /var/lib/dnf/metadata_lock.pid /var/run/dnf.pid >/dev/null 2>&1; do
  echo "Waiting for other package manager to finish..."
  sleep 5
done

# 2. 필수 패키지 설치 (dnf clean으로 캐시 꼬임 방지)
dnf clean all
dnf install -y nginx python3 python3-pip
# Flask 및 Gunicorn 설치
pip3 install flask gunicorn

# 3. Flask API 앱 작성 (상세 메타데이터 포함)
cat << 'EOF' > /home/ec2-user/app.py
from flask import Flask, render_template_string  
import random
import socket
import platform
import subprocess
import requests

app = Flask(__name__)

# HTML 템플릿 (Bootstrap 적용)
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
    # IMDSv2 토큰 가져오기
    token_url = "http://169.254.169.254/latest/api/token"
    token = requests.put(token_url, headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"}).text
    # 메타데이터 요청
    url = f"http://169.254.169.254/latest/meta-data/{path}"
    return requests.get(url, headers={"X-aws-ec2-metadata-token": token}).text

@app.route('/')
def simulate():
    # 몬테카를로 시뮬레이션
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

    # JSON 대신 HTML 템플릿 반환
    return render_template_string(HTML_TEMPLATE, data=result_data)

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
ExecStart=/bin/sh -c '/usr/local/bin/gunicorn --workers $(( $(nproc) * 2 )) --bind 127.0.0.1:8080 app:app'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. 서비스 시작
systemctl daemon-reload
systemctl enable nginx flask-api
systemctl start nginx flask-api

#7. docker 설치 및 node-exporter 실행
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
# 9. node-exporter 실행 (가장 중요한 부분!)
# -p 대신 --net=host를 써야 호스트(EC2) 메트릭을 정확히 가져옵니다.
docker run -d --name node_exporter --restart always --net="host" --pid="host" -v "/:/host:ro,rslave" \
  prom/node-exporter:latest --path.rootfs=/host
