## 카나리(Canary) 및 블루/그린(Blue-Green) ##

ALB의 가중치 기반 타겟 그룹(Weighted Target Groups) 라우팅을 활용하면 카나리 및 블루/그린 배포 전략을 효과적으로 구현할 수 있다. 먼저 신규 그라비톤 대상 그룹(tg-arm)을 생성한 후, 리스너 규칙의 가중치를 0%로 설정하여 추가함으로써 기존 서비스 중단 없이 신규 인스턴스를 등록하고 헬스 체크를 완료할 수 있다. 이후 비즈니스 요구사항에 맞춰 가중치 비율을 점진적으로 조정하여 안전하게 트래픽을 전환한다.

* 유연한 전환: 가중치는 0에서 999 사이의 정수로 설정 가능하며, 무중단으로 즉시 변경할 수 있다.
* 고급 활용: 특정 사용자(예: 특정 헤더 소유자)만 신규 그라비톤 그룹으로 보내 테스트하고 싶다면, 고급 요청 라우팅 규칙을 함께 결합하여 더 정교한 카나리 테스트가 가능하다.
* 고정 세션: 가중치 기반 라우팅 사용 시에도 대상 그룹 유지(Target Group Stickiness) 설정을 통해 사용자가 동일한 버전의 애플리케이션에 계속 머물도록 보장할 수 있다.

![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/my-alb-before.png)

```
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=graviton-mig" --query "Vpcs[0].VpcId" --output text)
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "Subnets[?MapPublicIpOnLaunch==\`false\`].SubnetId" \
    --output text | tr '[:space:]' ',' | sed 's/,$//')

echo "VPC_ID: ${VPC_ID}"
echo "AMI_ID: ${AMI_ID}"
echo "PRIVATE_SUBNET_IDS: ${SUBNET_IDS}"
```

#### 1. 타겟그룹 생성 ####
```
TG_ARN=$(aws elbv2 create-target-group --name tg-arm \
    --protocol HTTP --port 80 --vpc-id ${VPC_ID} --target-type instance --health-check-path "/" \
    --query "TargetGroups[0].TargetGroupArn" --output text)

echo "Target Group Created: ${TG_ARN}"
```
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/tg-arm-not-associated.png)

#### 2. 론치 템플릿 생성 ####

```
LAUNCH_TEMPLATE="asg-lt-arm"
LAUNCH_TEMPLATE_VERSION=1
USER_DATA_BASE64=$(base64 ~/get-started-eks/ec2/cf/monte-carlo.sh | tr -d '\n')

cat <<EOF > lt-data.json
{
    "ImageId": "${AMI_ID}",
    "InstanceType": "c7g.2xlarge",
    "UserData": "${USER_DATA_BASE64}",
    "MetadataOptions": {
        "InstanceMetadataTags": "enabled",
        "HttpTokens": "required",
        "HttpEndpoint": "enabled"
    },
    "TagSpecifications": [
        {
            "ResourceType": "instance",
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "arm-nginx"
                }
            ]
        }
    ]
}
EOF

aws ec2 create-launch-template \
    --launch-template-name "${LAUNCH_TEMPLATE}" \
    --launch-template-data file://lt-data.json \
    --query 'LaunchTemplateVersion.[LaunchTemplateName, VersionNumber]' \
    --output table
```

#### 3. Graviton 오토 스케일링 그룹 생성 ####
```
ASG_NAME="asg-graviton"

aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "${ASG_NAME}" \
    --launch-template "LaunchTemplateName=${LAUNCH_TEMPLATE},Version=${LAUNCH_TEMPLATE_VERSION}" \
    --target-group-arns "${TG_ARN}" \
    --min-size 2 --max-size 4 --desired-capacity 2 \
    --vpc-zone-identifier "${SUBNET_IDS}"
```
타겟 그룹과 ASG 를 연결한다.
```
aws autoscaling attach-load-balancer-target-groups \
    --auto-scaling-group-name "${ASG_NAME}" \
    --target-group-arns "${TG_ARN}"
```

#### 4. 리스너에 타켓그룹 등록 ####
```
ALB_ARN=$(aws elbv2 describe-load-balancers --names "my-alb" \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "${ALB_ARN}" --query "Listeners[].[ListenerArn]" --output text)

echo "ALB_ARN: ${ALB_ARN}"
echo "LISTENER_ARN: ${LISTENER_ARN}"

aws elbv2 modify-listener \
    --listener-arn "${LISTENER_ARN}" \
    --default-actions Type=forward,TargetGroupArn="${TG_ARN}"
```

#### 5. 트래픽 비율조정 ####
* 카나리: x86 그룹: 95% / graviton 그룹: 5%로 설정하여 신규(Graviton) 인스턴스로 소량의 트래픽만 흘려보내 성능 및 안정성 검증.
* 블루/그린: 검증이 끝나면 x86 그룹: 0% / graviton 그룹: 100%로 가중치를 변경하여 서비스를 전환.



## ALB 의 이해 ##

### 1. 각 구성 요소의 역할 ###
* ALB (Application Load Balancer): 모든 클라이언트 요청이 처음 도달하는 단일 접점.
* Listener: 특정 포트(예: 80)로 들어오는 요청을 기다린다. 한 ALB에 여러 포트를 열 수 있음.
* Rules: 리스너 내부에 위치하며, 조건(URL 경로, 호스트 이름 등)에 따라 요청을 특정 Target Group으로 전달(Forward).
* Target Group (TG): 로드밸런서가 요청을 보낼 실제 대상(인스턴스 등)들의 묶음. 각 대상의 상태 확인(Health Check)을 담당하여 정상인 곳으로만 트래픽을 보냄.
* Auto Scaling Group (ASG): 설정한 기준(CPU 사용률 등)에 따라 인스턴스 개수를 조절. ASG를 타겟 그룹에 연결해두면, 인스턴스가 새로 생성될 때마다 자동으로 타겟 그룹에 등록되어 즉시 트래픽을 받을 수 있게 됨.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-asg.png)

#### 액션 ####
* 트래픽의 최종 목적지: 리스너는 들어오는 트래픽을 감시하지만, 실제로 이 트래픽을 어디로 보낼지(forward 액션), 리다이렉트할지(redirect 액션), 혹은 고정 응답을 보낼지(fixed-response 액션)는 반드시 액션이 결정.
* 기본 규칙(Default Rule): 모든 리스너는 최소 하나 이상의 기본 규칙(Default Rule)과 그에 연결된 액션을 가져야 한다. 이 기본 규칙은 다른 모든 규칙이 일치하지 않았을 때 마지막에 실행.
* 역할 분담: Rules 블록이 API-TG 또는 WEB-TG로 트래픽을 forward 하라는 액션을 명시하고 있는데, 이 액션이 없으면 트래픽이 어디로 가야 할지 로드밸런서가 판단할 수 없다.

### 2. ASG 와 TG 와의 관계 ###
오토 스케일링 그룹(ASG)과 타겟 그룹(Target Group)이 연관되는 이유는 "트래픽 배달의 자동화" 때문으로, 이 둘은 트래픽 전달과 상태 관리라는 두 가지 핵심적인 역할을 위해 긴밀하게 작동한다.

#### 1. 신규 인스턴스의 자동 등록 (Scale-out) ####
ASG가 부하를 감지해 인스턴스를 새로 생성하면, 이 인스턴스는 아직 로드밸런서(ALB)가 모르는 상태이다.
ASG가 새 인스턴스의 IP/ID를 타겟 그룹에 자동으로 등록(Register)한 이후에 로드밸런서가 트래픽을 보낼 수 있다.

#### 2. 제거될 인스턴스의 자동 해제 (Scale-in) ####
반대로 부하가 줄어 인스턴스를 끌 때, 갑자기 꺼버리면 처리 중이던 요청이 끊기게 된다.
ASG가 타겟 그룹에 신호를 보내 해당 인스턴스를 Deregistration Delay(Draining) 상태로 만들고, 기존 요청이 다 처리될 때까지 기다린 후 안전하게 인스턴스를 제거한다.

#### 3. 정교한 상태 확인 (Health Check) ####
* ASG 자체 체크: 인스턴스가 켜져 있는가(EC2 Status) 만 확인.
* 타겟 그룹 체크: 실제 서비스(예: Flask 8080)가 응답하는가를 확인.
ASG가 타겟 그룹의 헬스 체크 결과를 참고하게 설정하면, 인스턴스는 살아있지만 앱이 뻗은 경우(Unhealthy) 이를 자동으로 죽이고 새 인스턴스를 띄울수 있다.




