## 카나리(Canary) 및 블루/그린(Blue-Green) 구현 ##
ALB 의 리스너 규칙에 두 개의 타겟 그룹을 연결하고 가중치를 부여하면 카나리 및 블루/그린 배포를 구현할 수 있다.
설정 방법은 ALB 리스너 편집 → 규칙(Rule) 수정 → 전달 대상(Forward to)에 기존 타겟그룹에 신규 타겟그룹 추가하는 것이다.

#### 가중치 조절: ####
* 카나리: x86 그룹: 95% / graviton 그룹: 5%로 설정하여 신규(Graviton) 인스턴스로 소량의 트래픽만 흘려보내 성능 및 안정성 검증.
* 블루/그린: 검증이 끝나면 x86 그룹: 0% / graviton 그룹: 100%로 가중치를 변경하여 서비스를 전환.

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
TG_ARN=$(aws elbv2 create-target-group --name tg-graviton \
    --protocol HTTP --port 80 --vpc-id ${VPC_ID} --target-type instance --health-check-path "/" \
    --query "TargetGroups[0].TargetGroupArn" --output text)

echo "Target Group Created: ${TG_ARN}"
```

#### 2. 론치 템플릿 생성 ####
```
LAUNCH_TEMPLATE="lt-arm"
LAUNCH_TEMPLATE_VERSION=1

cat <<EOF > lt-data.json
{
    "ImageId": "${AMI_ID}",
    "InstanceType": "c7g.2xlarge",
    "UserData": "file://~/get-started-eks/ec2/cf/monte-carlo.sh"
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



## ASG 와 TG 와의 관계 ##
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




