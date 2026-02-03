
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
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    ec2_sd_configs:
      - region: ap-northeast-2
        port: 9100
    relabel_configs:
      # VPC ID로도 필터링 가능
      - source_labels: [__meta_ec2_vpc_id]
        regex: 'vpc-0123456789abcdef0'
        action: keep
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
```
* IAM 권한: 프로메테우스 서버가 ec2:DescribeInstances 권한을 가지고 있어야 한다.
* 포트 접근: 수집 대상 EC2의 보안 그룹에서 프로메테우스 서버의 IP에 대해 9100번 포트가 열려 있어야 하다.

스택을 설치한다. 
```
docker-compose up -d
```


