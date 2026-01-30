  #!/bin/bash
  dnf update -y
  dnf install -y nginx
  
  # IMDSv2 토큰 가져오기 (메타데이터 접근용)
  TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  
  # 인스턴스 정보 추출
  IP_PRIVATE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
  INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)
  INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
  HOSTNAME=$(hostname)
  ARCH=$(uname -m)
  CPU_INFO=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
  MEM_INFO=$(free -h | awk '/^Mem:/ {print $2}')

  # HTML 파일 생성
  cat <<EOF > /usr/share/nginx/html/index.html
  <html>
  <head><title>EC2 Status</title></head>
  <body>
    <h1>EC2 Instance Information</h1>
    <p><b>Instance Type:</b> $INSTANCE_TYPE</p>             
    <p><b>Instance Id:</b> $INSTANCE_ID</p>
    <p><b>Architecture:</b> $ARCH</p>
    <p><b>Private IP:</b> $IP_PRIVATE</p>
    <p><b>Hostname:</b> $HOSTNAME</p>
    <p><b>CPU:</b> $CPU_INFO</p>
    <p><b>Memory:</b> $MEM_INFO</p>
    <hr>
    <p>Generated at: $(date)</p>
  </body>
  </html>
  EOF

  systemctl start nginx
  systemctl enable nginx
