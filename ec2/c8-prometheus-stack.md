
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
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['<TARGET_EC2_PRIVATE_IP>:9100'] # Node Exporter가 설치된 IP
```

스택을 설치한다. 
```
docker-compose up -d
```


