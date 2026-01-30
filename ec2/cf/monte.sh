yum update -y
yum install -y nginx python3 python3-pip

# 2. Flask 및 Gunicorn 설치
pip3 install flask gunicorn

# 3. Flask API 앱 작성
cat << 'EOF' > /home/ec2-user/app.py
from flask import Flask, jsonify
import random

app = Flask(__name__)

@app.route('/')
def simulate():
    # 실시간 몬테카를로 계산 (10만 번 수행)
    n = 100000
    hits = sum(1 for _ in range(n) if random.random()**2 + random.random()**2 <= 1.0)
    pi_estimate = 4.0 * hits / n
    return jsonify({
        "status": "success",
        "pi_estimate": pi_estimate,
        "iterations": n,
        "architecture": "Graviton/ARM64"
    })

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
EOF

# 4. Nginx Reverse Proxy 설정
# 80번 포트로 들어온 요청을 Flask(8080포트)로 전달
cat << 'EOF' > /etc/nginx/conf.d/proxy.conf
server {
    listen 80;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# 기존 기본 설정과 충돌 방지
rm -f /etc/nginx/conf.d/default.conf

# 5. Gunicorn을 Systemd 서비스로 등록 (백그라운드 실행)
cat << EOF > /etc/systemd/system/flask-api.service
[Unit]
Description=Gunicorn instance to serve Monte Carlo API
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/local/bin/gunicorn --workers 3 --bind 127.0.0.1:8080 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. 모든 서비스 시작
systemctl daemon-reload
systemctl enable nginx flask-api
systemctl start nginx flask-api
