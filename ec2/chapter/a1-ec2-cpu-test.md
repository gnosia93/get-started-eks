### # k6 설치 ###
```
sudo dnf install -y https://dl.k6.io/rpm/repo.rpm
sudo dnf install -y k6
```
* vscode 서버에 프로메테우스를 아직 설치하지 않았다면 [프로메테우스 스택 설치하기](https://github.com/gnosia93/get-started-eks/blob/main/ec2/chapter/c6-prometheus-stack.md)를 참고하여 모니터링 환경을 구축 한다.
  
### # 인스턴스 생성 ###
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

#!/bin/bash
# 인스턴스 생성 함수 정의
launch_ec2() {
    local INST_TYPE=$1
    local TAG_NAME=$2
    local ARCH=$3  # x86_64 또는 arm64

    echo "[$INST_TYPE] AMI ID 조회 중..."
    AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$ARCH \
      --query "Parameters[0].Value" --output text)

    echo "[$INST_TYPE / $ARCH] 인스턴스 생성 시작..."
    INST_ID=$(aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
        --instance-type "${INST_TYPE}" \
        --key-name "${KEY_NAME}" \
        --subnet-id "${SUBNET_ID}" \
        --security-group-ids "${SG_ID}" \
        --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
        --metadata-options "InstanceMetadataTags=enabled" \
        --monitoring "Enabled=true" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${TAG_NAME}}]" \
        --query 'Instances[0].InstanceId' --output text)

    #echo "[$INST_TYPE] Running 상태 대기 중 ($INST_ID)..."
    #aws ec2 wait instance-running --instance-ids "$INST_ID"

    # 공인 IP 추출 및 파일 저장 (누적 기록)
    #PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INST_ID" \
    #    --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

    PRIVATE_IP=$(aws ec2 describe-instances --instance-ids "$INST_ID" \
        --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text)

    echo "$INST_TYPE $TAG_NAME $PRIVATE_IP" >> ALL_INST_IPS
    echo "[$INST_TYPE] 생성 완료: $PRIVATE_IP"
}

# 1. 인스턴스 타입 배열 정의
instance_types=( "c5.2xlarge" "c6g.2xlarge" "c6i.2xlarge" "c7g.2xlarge" "c7i.2xlarge" "c8g.2xlarge" "c8i.2xlarge" )

# 2. 루프 실행
for type in "${instance_types[@]}"; do

    family=$(echo $type | cut -d'.' -f1)
    if [[ $family == *"g"* ]]; then
        ARCH="arm64"
    else
        ARCH="x86_64"
    fi
    
    launch_ec2 "$type" "pt-$type" "$ARCH"
done

cat ALL_INST_IPS
```

### # 성능 테스트 ###

스크립트 파일을 생성한다. 
```
cat <<EOF > k6-script.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // Graviton3의 높은 코어 효율을 확인하기 위해 단계를 세분화
  stages: [
    { duration: '3m', target: 100 },        // 웜업: VU 100 명까지 증가
    { duration: '10m', target: 400 },       // 부하: 400명 유지 (시뮬레이션 연산 부하 확인)
    { duration: '2m', target: 0 },          // 쿨다운
  ],
  thresholds: {
    // 시뮬레이션 특성상 응답 시간이 길 수 있으므로 p95 기준을 2초로 넉넉히 설정
    'http_req_duration': ['p(95)<2000'],
    'http_req_failed': ['rate<0.01'],
  },
};

export default function () {
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
    },
    timeout: '60s',                         // 연산 시간에 대한 타임 아웃 설정값
  };

  const res = http.get('#BASE_URL#/', params);
  check(res, {
    'is status 200': (r) => r.status === 200,
  });

  sleep(0.5);                               // 가상 유저(VU)의 http 요청 간격 - 요청 보낸 후 0.5초씩 휴식
}
EOF
```

개별 인스턴스에 대한 성능 테스트를 실행한다.
```
while read -r INST_TYPE HOSTNAME IP_ADDR; do    
    export BASE_URL="http://$IP_ADDR"
    echo "현재 실행 중: $INST_TYPE (BASE_URL: $BASE_URL)"
    cat k6-script.js | sed "s|#BASE_URL#|$BASE_URL|g" | k6 run --out "web-dashboard=report=$HOSTNAME.html" -
done < ALL_INST_IPS
```

[결과]
```
현재 실행 중: c5.2xlarge (BASE_URL: http://10.0.1.148)

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: -
 web dashboard: http://127.0.0.1:5665
        output: -

     scenarios: (100.00%) 1 scenario, 400 max VUs, 15m30s max duration (incl. graceful stop):
              * default: Up to 400 looping VUs for 15m0s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✗ 'p(95)<2000' p(95)=14.75s

    http_req_failed
    ✓ 'rate<0.01' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 22128   24.570699/s
    checks_succeeded...: 100.00% 22128 out of 22128
    checks_failed......: 0.00%   0 out of 22128

    ✓ is status 200

    HTTP
    http_req_duration..............: avg=7.83s min=163.16ms med=7.86s max=15.61s p(90)=14.01s p(95)=14.75s
      { expected_response:true }...: avg=7.83s min=163.16ms med=7.86s max=15.61s p(90)=14.01s p(95)=14.75s
    http_req_failed................: 0.00%  0 out of 22128
    http_reqs......................: 22128  24.570699/s

    EXECUTION
    iteration_duration.............: avg=8.33s min=663.53ms med=8.36s max=16.11s p(90)=14.51s p(95)=15.25s
    iterations.....................: 22128  24.570699/s
    vus............................: 2      min=1          max=400
    vus_max........................: 400    min=400        max=400

    NETWORK
    data_received..................: 43 MB  47 kB/s
    data_sent......................: 2.7 MB 3.0 kB/s




running (15m00.6s), 000/400 VUs, 22128 complete and 0 interrupted iterations
default ✓ [======================================] 000/400 VUs  15m0s
ERRO[0900] thresholds on metrics 'http_req_duration' have been crossed 
현재 실행 중: c6g.2xlarge (BASE_URL: http://10.0.1.177)

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: -
 web dashboard: http://127.0.0.1:5665
        output: -

     scenarios: (100.00%) 1 scenario, 400 max VUs, 15m30s max duration (incl. graceful stop):
              * default: Up to 400 looping VUs for 15m0s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)


running (03m46.7s), 123/400 VUs, 5459 complete and 0 interrupted iterations
default   [========>-----------------------------] 123/400 VUs  03m46.7s/15m00.0s

...
```

### # 웹 대시보드 ###
* 시큐리티 그룹 5665 port 오픈 필요
* http://[your vscode-ip]:5665
  
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/k6-web-dashboard.png)

* c8i.2xlarge - 
* c8g.2xlarge - 50.08%
* c7i.2xlarge - 49.47%
* c7g.2xlarge - 55.74%
* c6i.2xlarge - 65.60%
* c6g.2xlarge - 68%
* c5.2xlarge - 100%


## Reference ##
* https://docs.aws.amazon.com/ko_kr/ec2/latest/instancetypes/ec2-instance-regions.html
