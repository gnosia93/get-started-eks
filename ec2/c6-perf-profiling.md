## [Aperf](https://github.com/aws/aperf) ##
AWS에서 제작한 오픈 소스 명령줄(CLI) 성능 분석 도구로, 리눅스 시스템에서 여러 도구(perf, sysstat, sysctl 등)를 통해 수집하던 다양한 성능 데이터를 하나로 모아서 보여주고, 이를 HTML 리포트로 시각화한다. 

### 1. 사전 준비 (Graviton/Linux) ###
grav-nginx-perf 그라비톤 인스턴스를 ssh 로 로그인하여 아래 명령어를 실행한다.
```
# PMU 접근 허용
echo 0 | sudo tee /proc/sys/kernel/perf_event_paranoid

# 파일 오픈 제한 상향
sudo ulimit -n 65536
```
aperf 와 perf 를 설치한다.
```
wget https://github.com/aws/aperf/releases/download/v1.1.0/aperf-v1.1.0-aarch64.tar.gz
tar xvfz aperf-v1.1.0-aarch64.tar.gz
sudo cp aperf-v1.1.0-aarch64/aperf /usr/local/bin/

sudo dnf install -y perf
```

### 2. 프로파일링 데이터 수집 (record) ### 
Python 스크립트를 실행하면서 시스템 및 CPU 지표를 기록한다. --profile 플래그를 추가하면 CPU 프로파일링 정보가 포함된다.
```
rm report 2>>/dev/null 
aperf record -r graviton -i 1 -p 60 --profile -v
```

### 3. 결과 리포트 생성 (report) ###
수집된 데이터를 시각화된 HTML 리포트로 변환해서 nginx 디렉토리로 옮긴다 
```
aperf report -r graviton -n perf-report -v
sudo cp -R perf-report /usr/share/nginx/html/
```

proxy.conf 에 /perf-report 경로를 등록한다.
```
sudo vi /etc/nginx/conf.d/proxy.conf
```
[proxy.conf]
```
server {
    listen 80;

    # 1. aperf 리포트 경로 추가 (우선순위 높음)
    location /perf-report {
        alias /usr/share/nginx/html/perf-report;
        index report.html index.html;
        autoindex on;
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
```
nginx 를 재시작한다.
```
sudo nginx -t
sudo systemctl restart nginx
```

### 4. 리포트 확인 ###
http://[grav-nginx-perf]/perf-report/ 에 접속해서 리포트를 확인한다. 

![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/aperf-data.png)

## 프로세스 분석 (py-spy) ##
Gunicorn은 여러 개의 워커(Worker) 프로세스를 띄워 동작하므로, 개별 프로세스뿐만 아니라 전체 구조를 파악할 수 있는 도구를 선택하는 것이 중요하다.
py-spy(GitHub)는 오버헤드가 매우 적어 운영 환경에서도 비교적 안전하게 사용 가능하고, 서비스 중단 없이 실행 중인 Gunicorn 워커에 바로 연결해 성능을 측정할 수 있다.  
```
pip install py-spy
```

리눅스의 top 명령어처럼, 어떤 함수가 CPU 시간을 가장 많이 점유하고 있는지 실시간으로 보여준다
```
sudo py-spy top --pid <worker_pid>
```

프레임 그래프 생성하는 명령어로 어떤 함수에서 시간이 많이 소요되는지 시각화한다. --subprocesses 옵션을 쓰면 Gunicorn 마스터 프로세스를 지정해도 하위 워커들을 함께 분석할 수 있다.
```
sudo py-spy record -o profile.svg --pid <gunicorn_master_pid> --subprocesses
```
