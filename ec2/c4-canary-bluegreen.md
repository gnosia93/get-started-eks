## 카나리(Canary) 및 블루/그린(Blue-Green) 구현 ##
ALB 의 리스너 규칙에 두 개의 타겟 그룹을 연결하고 가중치를 부여하면 카나리 및 블루/그린 배포를 구현할 수 있다.
설정 방법은 ALB 리스너 편집 → 규칙(Rule) 수정 → 전달 대상(Forward to)에 기존 타겟그룹에 신규 타겟그룹 추가하는 것이다.
* 가중치 조절:
  * 카나리: x86 그룹: 95% / graviton 그룹: 5%로 설정하여 신규(Graviton) 인스턴스로 소량의 트래픽만 흘려보내 성능 및 안정성 검증.
  * 블루/그린: 검증이 끝나면 x86 그룹: 0% / graviton 그룹: 100%로 가중치를 변경하여 서비스를 전환.

* ALB 리스너 편집 → 규칙(Rule) 수정
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-listener-edit.png)

* 전달 대상(Forward to) 수정
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-listener-add-target-group.png)


#### 1. 신규 타겟그룹 생성 ####

```
TG_NAME="tg-graviton"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=graviton-mig" --query "Vpcs[0].VpcId" --output text)
echo "VPC_ID: ${VPC_ID}"

# 타겟 그룹 생성 (Instance 타입)
TG_ARN=$(aws elbv2 create-target-group \
    --name ${TG_NAME} \
    --protocol HTTP \
    --port 80 \
    --vpc-id ${VPC_ID} \
    --target-type instance \
    --health-check-path "/" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)

echo "Target Group Created: ${TG_ARN}"
```

#### 2. Graviton 용 ASG 생성 ####
```
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "asg-graviton-v2" \
    --launch-template "LaunchTemplateName=${LAUNCH_TEMPLATE},Version=\$Latest" \
    --target-group-arns "${NEW_TG_ARN}" \
    --min-size 1 --max-size 5 --desired-capacity 2 \
    --vpc-zone-identifier "subnet-xxxxxx"
```
타겟 그룹과 ASG 를 연결한다.
```
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${ASG_NAME}" \
    --target-group-arns "${TG_ARN}"
```


#### 3. 리스너에 타켓그룹 등록 ####
```
aws elbv2 modify-listener \
    --listener-arn "리스너_ARN_입력" \
    --default-actions '[
        {
            "Type": "forward",
            "ForwardConfig": {
                "TargetGroups": [
                    {
                        "TargetGroupArn": "기존_TG_ARN",
                        "Weight": 100
                    },
                    {
                        "TargetGroupArn": "신규_Graviton_TG_ARN",
                        "Weight": 0
                    }
                ]
            }
        }
    ]'
```
* 리스너 ARN 확인: aws elbv2 describe-listeners --load-balancer-arn "ALB_ARN" 명령어로 리스너 ARN을 먼저 확인하세요.
* 상태 확인: 타겟 그룹을 등록한 직후에는 Target Groups의 Health Check가 Healthy로 바뀌는지 모니터링해야 트래픽이 정상적으로 흐릅니다.


#### 4. 트래픽 비율조정 ####


### 참고 - Graviton 용으로 ASG 를 별도로 만드는 이유 ###
* 바이너리 호환성: ASG는 하나의 '시작 템플릿'만 사용하는데, 템플릿에 arm64(Graviton) AMI를 넣으면 ASG가 띄우는 모든 인스턴스가 Graviton이 된다.
* 동시 공급의 문제: 하나의 ASG에 TG-A, TG-B를 연결하면, ASG가 생성하는 모든 인스턴스가 두 타겟 그룹에 동시에 등록된다. 



