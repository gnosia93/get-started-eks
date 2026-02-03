
### docker 설치 ###


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
prometheus.yml 설정 파일을 생성한다. 
```
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -s -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
echo ${AWS_REGION}

export VPC_ID=$(aws cloudformation describe-stacks --stack-name graviton-mig-stack \
  --query "Stacks[0].Outputs")
echo ${VPC_ID}
```

```
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    ec2_sd_configs:
      - region: ap-northeast-2
        port: 9100
    relabel_configs:
      # VPC ID로도 필터링 가능
      - source_labels: [__meta_ec2_vpc_id]        # 1. AWS에서 가져온 'VPC ID'라는 데이터에서
        regex: 'vpc-0123456789abcdef0'            # 2. 값이 일치하는지 검사한 뒤
        action: keep                              # 3. 맞으면 남기고 틀리면 버린다.
      - source_labels: [__meta_ec2_tag_Name]      # 1. EC2 인스턴스의 Name 태그 값 
        target_label: instance                    # 2. 프로메테우스와 그라파나에서 서버를 식별하는 라벨인 instance 에 가져온 값을 Update. 
```
* IAM 권한: 프로메테우스 서버가 ec2:DescribeInstances 권한을 가지고 있어야 한다.
* 포트 접근: 수집 대상 EC2의 보안 그룹에서 프로메테우스 서버의 IP에 대해 9100번 포트가 열려 있어야 하다.

스택을 설치한다. 
```
docker-compose up -d
```


