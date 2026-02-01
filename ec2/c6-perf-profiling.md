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
aperf record -r graviton -i 1 -p 60 --profile -v
```
명령어가 완료되면 run1/ 디렉토리와 run1.tar.gz 파일이 생성된다.

#### 3. 결과 리포트 생성 및 확인 (report) ####
수집된 데이터를 시각화된 HTML 리포트로 변환한다 (index.html 생성)
```
aperf report -r run1 -n perf-report
```
* CPU Usage Plot: 시간 경과에 따른 CPU 사용량 변화를 보여준다.
* Flame Graph: --profile 옵션을 사용했다면, 어떤 Python 함수나 시스템 호출이 CPU를 많이 점유했는지 시각적으로 파악할 수 있다.
* PMU Events: Graviton 아키텍처 특유의 하드웨어 카운터(캐시 미스, 분기 예측 등) 정보를 확인할 수 있다.
Python 3.12 이상을 사용 중이라면 PYTHON_PERF_JIT_SUPPORT=1 환경 변수를 설정하고 실행하면 리포트에서 Python 함수 이름이 더 정확하게 노출된다.


## 레퍼런스 ##

* https://github.com/aws/aperf
