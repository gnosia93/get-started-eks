<< 작성중; 제대로 된 샘플을 만들기에는 시간이 필요하다 >>

## 프로파일링 도구 ##

### 1. APerf (AWS Perf) ###
AWS에서 Graviton 프로세서의 성능 분석을 위해 만든 오픈소스 도구로 perf, sysstat 등의 데이터를 수집하여 HTML 리포트로 시각화해 준다.

### 2. Py-Spy ###
Py-Spy 는 코드를 수정하거나 프로그램을 재시작하지 않고도 실행 중인 Python 프로세스에 연결하여 프로파일링할 수 있다. Rust로 작성되어 매우 빠르며, ARM64를 지원하여 Graviton 환경에서도 실시간으로 스택 정보를 확인하거나 플레임 그래프(Flame Graph)를 생성하는 데 유용하다.
```
py-spy record -o profile.svg --python my_script.py
```
### 3. async-profiler ###
async-profiler는 JVM(Java Virtual Machine) 환경에서 성능 병목 지점을 찾기 위해 설계된 가장 정교한 오픈소스 프로파일러 중 하나이다.

### 4. Amazon CodeGuru Profiler ### 
Lambda나 EC2에서 실행되는 Python 애플리케이션의 성능을 지속적으로 모니터링할 수 있다. 현재 Python 3.7~3.9 버전을 지원하며, 시각적인 플레임 그래프와 성능 개선 권장 사항을 제공한다.


## aperf 사용 방법 ##
AWS Graviton 환경에서 APerf(AWS Perf)를 사용해 Python을 프로파일링하는 과정은 크게 데이터 수집(Record)과 리포트 생성(Report) 두 단계로 나뉜다.

#### 1. 사전 준비 (Graviton/Linux) ####
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

#### 2. 프로파일링 데이터 수집 (record) #### 
Python 스크립트를 실행하면서 시스템 및 CPU 지표를 기록한다. --profile 플래그를 추가하면 CPU 프로파일링 정보가 포함된다.
```
rm report 2>>/dev/null 
aperf record -r graviton -i 1 -p 60 --profile -v
```

#### 3. 결과 리포트 생성 및 확인 (report) ####
수집된 데이터를 시각화된 HTML 리포트로 변환한다 
```
aperf report -r graviton -n perf-report -v
sudo cp -R perf-report /usr/share/nginx/html/
```

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
~
```



## 레퍼런스 ##

* https://github.com/aws/aperf
