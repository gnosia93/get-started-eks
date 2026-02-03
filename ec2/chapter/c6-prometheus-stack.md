## 프로메테우스 스택 설치하기 ##

vscode 서버의 터미널에서 아래 docker 와 프로메테우스 스택을 설치한다. 

### docker 설치 ###
```
sudo dnf update -y
sudo dnf install -y docker
sudo usermod -a -G docker ec2-user

sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

sudo systemctl status docker
sudo systemctl start docker
sudo systemctl enable docker

newgrp docker

docker run -d --name node_exporter --restart always --net="host" --pid="host" -v "/:/host:ro,rslave" \
  prom/node-exporter:latest --path.rootfs=/host

docker --version
docker-compose --version
```


### 프로메테우스 스택 설치 ###
Prometheus 및 Grafana 컨테이너를 정의하는 docker-compose.yml 파일을 생성한다.
```
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: always

  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    restart: always
EOF
```

VPC_ID 를 조회하고, prometheus.yml 설정 파일을 생성한다. 
```
export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -s -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="graviton-mig" --query "Vpcs[].VpcId" --output text)
echo ${VPC_ID}

cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    ec2_sd_configs:
      - region: ap-northeast-2
        port: 9100
        filters:
          - name: vpc-id
            values:
              - ${VPC_ID}
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
EOF
```
* IAM 권한: 프로메테우스 서버가 ec2:DescribeInstances 권한을 가지고 있어야 한다.
* 포트 접근: 수집 대상 EC2의 보안 그룹에서 프로메테우스 서버의 IP에 대해 9100번 포트가 열려 있어야 하다.

스택을 설치한다. 
```
docker-compose up -d
```
[결과]
```
+] Running 22/22
 ✔ prometheus 10 layers [⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿]      0B/0B      Pulled                                                                                             5.4s 
   ✔ 9d85dc8d0609 Pull complete                                                                                                                         0.6s 
   ✔ d0f7326b7716 Pull complete                                                                                                                         0.6s 
   ✔ 3dccafa3f67b Pull complete                                                                                                                         1.1s 
   ✔ d956c9c5fe9e Pull complete                                                                                                                         1.5s 
   ✔ 1d8e8fd2e272 Pull complete                                                                                                                         1.2s 
   ✔ 1dccce9f415d Pull complete                                                                                                                         1.7s 
   ✔ e5d54fbf8ee1 Pull complete                                                                                                                         1.8s 
   ✔ 37404d8f503a Pull complete                                                                                                                         2.0s 
   ✔ b30c77c91326 Pull complete                                                                                                                         2.3s 
   ✔ d76a56e8adff Pull complete                                                                                                                         2.4s 
 ✔ grafana 10 layers [⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿]      0B/0B      Pulled                                                                                               11.4s 
   ✔ 014e56e61396 Pull complete                                                                                                                         2.7s 
   ✔ 9d54a595d298 Pull complete                                                                                                                         2.8s 
   ✔ ec479bafece9 Pull complete                                                                                                                         3.0s 
   ✔ c00447c3619a Pull complete                                                                                                                         3.3s 
   ✔ 07af56023d33 Pull complete                                                                                                                         3.4s 
   ✔ 0df2602ce2c1 Pull complete                                                                                                                         3.6s 
   ✔ 34a7268ff0f5 Pull complete                                                                                                                         4.7s 
   ✔ 671912a993db Pull complete                                                                                                                         4.7s 
   ✔ 9e053de6cb63 Pull complete                                                                                                                         4.3s 
   ✔ 6139928abb9b Pull complete                                                                                                                         4.9s 
[+] Running 2/3
 ⠏ Network ec2-user_default  Created                                                                                                                    8.9s 
 ✔ Container grafana         Started                                                                                                                    8.5s 
 ✔ Container prometheus      Started         
```

### 그라파나 로그인 ###

#### 1. 로그인 #### 
웹브라우저를 이용하여 vscode 서버의 3000번 포트를 접근한다. 그라파나의 초기 아이디와 패스워드는 admin/admin 이다.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/grafana-login.png)

#### 2. Data sources 등록 ####
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/grafana-datasource-add.png)
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/grafana-datasource-add-2.png)

#### 3. Dashboard 등록 ####
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/dashboard-add-1.png)
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/dashboard-add-2.png)
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/dashboard-add-3.png)

#### 4. Metric 관찰 ####
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/dashboard-metric.png)
