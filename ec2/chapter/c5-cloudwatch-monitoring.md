## 몬테 카를로 시뮬레이션 ##

몬테카를로 시뮬레이션은 불확실한 사건의 다양한 미래 결과를 예측하기 위해 무작위 추출과 반복 시뮬레이션을 사용하는 수학적/통계적 기법으로, 복잡한 문제의 근사적인 해를 구하는 데 유용하며, 난수(랜덤 넘버)를 생성하여 수백, 수천 번의 시나리오를 실행하고 그 결과를 분석해 확률적 분포를 파악한다. 수많은 난수(무작위 숫자)를 생성하고 반복적인 계산을 통해 불확실한 사건의 결과를 예측하는 기법으로, CPU의 순수 계산 능력을 극한으로 테스트하기에 매우 이상적인 도구이다. 

![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/perf-calro.png)

무작위 샘플링을 반복하여 결과를 도출하는 특성상 CPU의 순수 연산 성능을 측정하는 벤치마크 도구로 매우 훌륭하며, CPU 성능 측정 측면에서 몬테카를로 방식이 갖는 주요 강점은 다음과 같다.
* 병렬 처리 효율성: 각 샘플링 연산이 독립적이기 때문에 여러 CPU 코어에 작업을 분산하기 매우 수월한데, 이는 최신 멀티코어 CPU의 처리량을 테스트하는 데 최적이다.
* 부동 소수점 연산 집약적: 복잡한 확률 분포와 수치 적분 등을 계산하는 과정에서 방대한 양의 부동 소수점 연산이 발생하여 CPU의 산술 논리 장치(ALU) 부하를 효과적으로 측정할 수 있다.
* 확장성: 샘플링 횟수를 조절하는 것만으로 연산 강도를 자유롭게 설정할 수 있어, 가벼운 테스트부터 워크스테이션급의 극한 성능 테스트까지 모두 가능하다.

#### Gunicorn worker 수 - vCPU 의 2배 ####
```
ExecStart=/bin/sh -c '/usr/local/bin/gunicorn --workers $(( $(nproc) * 2 )) --bind 127.0.0.1:8080 app:app'
```

#### 어플리케이션 코드 ####
```
from flask import Flask, render_template_string  
import random
import socket
import platform
import subprocess
import requests

app = Flask(__name__)


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
```
성능 테스트 대상 워크로드는 python flask 웹서버로 실행되는 몬테카를로 시뮬레이션 어플리케이션이다. EC2 인스턴스의 Userdata 에 이미 자동으로 설치되도록 되어 있다.


## wrk 로드 제너레이터 ##

vscode 서버로 접속해서 터미널을 하나 열고 apache bench (ab) 와 wrk 를 설치한다
```
sudo dnf update -y
sudo dnf install httpd-tools -y

sudo yum groupinstall -y "Development Tools"
sudo yum install -y openssl-devel git
git clone https://github.com/wg/wrk.git
cd wrk
make && sudo cp wrk /usr/local/bin
wrk --version
```

웹 어플리케이션을 테스트 한다.
```
ALB_URL=$(aws cloudformation describe-stacks --stack-name graviton-mig-stack \
  --query "Stacks[0].Outputs[?OutputKey=='ALBURL'].OutputValue" \
  --output text | xargs)
echo "${ALB_URL}"

for i in {1..16}; do wrk -t16 -c160 -d600s -H "Connection: keep-alive" --latency "http://${ALB_URL}/" & done
```
* -t 스레드, -c 커넥션, -d 시간  



## Cloudwatch 모니터링 ##
Metrics > All metrics > EC2 하단의 View Automatic Dashboard 링크를 클릭한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/perf-dashboard.png)

### 3가지 핵심 비교 지표 ###

#### 1. 응답 속도 비교 (TargetResponseTime) ####
가장 중요한 지표로, Graviton이 기존 대비 얼마나 빠른지(혹은 느린지) 평균값과 P99(상위 1% 지연 시간)를 확인한다.

#### 2. 처리량 및 에러율 (RequestCount & HTTPCode_Target) ####
Graviton에서 애플리케이션이 안정적으로 동작하는지 확인한다.
* RequestCount: 가중치 설정(예: 8:2)대로 요청이 들어오고 있는지 확인.
* HTTPCode_Target_5XX_Count: Graviton TG에서만 에러가 발생하지 않는지 확인.

#### 3. CPU 사용량 및 비용 효율 (CPUUtilization) ####
인스턴스 자체의 CPU 부하를 비교하여, 가격대비 성능비를 계산한다.

## 인스턴스 성능 테스트 ##
vscode 서버에서 터미널을 열고 아래 명령어를 실행한다. 
```
export KEY_NAME="aws-kp-2"
export STACK_NAME="graviton-mig-stack"

SG_ID=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query "Stacks[0].Outputs[?OutputKey=='EC2SecurityGroupId'].OutputValue" \
  --output text)

SUBNET_ID=$(aws cloudformation describe-stack-resource \
  --stack-name ${STACK_NAME} \
  --logical-resource-id PublicSubnet1 \
  --query "StackResourceDetail.PhysicalResourceId" \
  --output text)

echo "SG_ID: ${SG_ID}, SUBNET_ID: ${SUBNET_ID}" 
```

### 그라비톤 ###
그라비톤 인스턴스를 생성한다. 퍼블릭 IP 를 출력하는 관계로 15초 정도의 시간이 소요된다.
```
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)

INST_ID=$(aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
    --instance-type c7g.2xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
    --metadata-options "InstanceMetadataTags=enabled" \
    --monitoring "Enabled=true" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=grav-nginx-perf}]' \
    --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$INST_ID"

aws ec2 describe-instances --instance-ids "$INST_ID" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text > GRAV_INST

cat GRAV_INST
```
AWS 콘솔을 확인하여 인스턴스의 Status 체크가 완료된 이후에(3/3 checks passed), wrk 로 그라비톤의 성능을 테스트한다. 
```
export EC2_URL="$(cat GRAV_INST)" 
export NUM_WRK=16

for i in $(seq 1 "${NUM_WRK}"); do
    wrk -t32 -c320 -d600s -H "Connection: keep-alive" --latency "http://${EC2_URL}/" &
done
```


### X86 ###
x86 인스턴스를 생성한다. 퍼블릭 IP 를 출력하는 관계로 15초 정도의 시간이 소요된다.
```
X86_AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameters[0].Value" --output text)

X86_INST_ID=$(aws ec2 run-instances --image-id ${X86_AMI_ID} --count 1 \
    --instance-type c6i.2xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
    --metadata-options "InstanceMetadataTags=enabled" \
    --monitoring "Enabled=true" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=x86-nginx-perf}]' \
    --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$X86_INST_ID"

aws ec2 describe-instances --instance-ids "$X86_INST_ID" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text > X86_INST

cat X86_INST
```
AWS 콘솔을 확인하여 인스턴스의 Status 체크가 완료된 이후에(3/3 checks passed), wrk 로 x86 인스턴스의 성능을 테스트 한다.
```
export EC2_URL="$(cat X86_INST)" 
export NUM_WRK=16

for i in $(seq 1 "${NUM_WRK}"); do
    wrk -t32 -c320 -d600s -H "Connection: keep-alive" --latency "http://${EC2_URL}/" &
done
```

### 성능비교 ###
CloudWatch 콘솔 > Metircs > All metrics > EC2 의 View automatic dashboard > CPU Utilization - Maximize CPU Utilization > View in metrics 선택 한다. 

* x86 - 99%
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/wrk-perf-by-thread-1.png)

* graviton - 67% 
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/wrk-perf-by-thread-2.png)
