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

for i in {1..16}; do wrk -t16 -c2000 -d600s --latency "http://${ALB_URL}/" & done
```
* -t 스레드, -c 커넥션, -d 시간  

## 몬테카를로 시뮬레이션 ##
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/perf-calro.png)
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
```

### 그라비톤 ###
```
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)

GRAVITON_INST=$(aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
    --instance-type c7g.2xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
    --metadata-options "InstanceMetadataTags=enabled" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=grav-nginx-perf}]' \
    --query 'Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress}' \
    --output table)
echo ${GRAVITON_INST}
```

```
export EC2_URL="10.0.1.201" 
export NUM_WRK=16

for i in $(seq 1 "${NUM_WRK}"); do
    wrk -t16 -c2000 -d300s --latency "http://${EC2_URL}/" &
done
```


### X86 ###
```
X86_AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameters[0].Value" --output text)

X86_INST=$(aws ec2 run-instances --image-id ${X86_AMI_ID} --count 1 \
    --instance-type c6i.2xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
    --metadata-options "InstanceMetadataTags=enabled" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=x86-nginx-perf}]' \
    --query 'Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress}' \
    --output table)
echo ${X86_INST}
```

```
export EC2_URL="54.180.247.185" 
export NUM_WRK=16

for i in $(seq 1 "${NUM_WRK}"); do
    wrk -t16 -c2000 -d300s --latency "http://${EC2_URL}/" &
done
```


## 레퍼런스 ##
* https://k6.io/

