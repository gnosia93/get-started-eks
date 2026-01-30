## 카나리(Canary) 및 블루-그린(Blue-Green) 구현 ##
ALB의 리스너 규칙에서 하나의 규칙에 두 개의 타겟 그룹을 연결하고 가중치를 부여하면 한다.
* 설정 방법: ALB 리스너 편집 → 규칙(Rule) 수정 → 전달 대상(Forward to)에 타겟그룹 A(기존/Blue)와 타겟그룹 B(신규/Green)를 모두 추가.
* 가중치 조절:
  * 카나리: A: 95% / B: 5%로 설정하여 신규(ARM) 인스턴스로 소량의 트래픽만 흘려보내 성능을 검증.
  * 블루-그린: 검증이 끝나면 A: 0% / B: 100%로 가중치를 변경하여 즉시 전환.

* ALB 리스너 편집 → 규칙(Rule) 수정
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-listener-edit.png)

* 전달 대상(Forward to) 수정
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-listener-add-target-group.png)


### AWS CLI 활용 ###

#### 1. 신규 타겟그룹 생성 ####

```
# 변수 설정
TG_NAME="tg-graviton-app"
VPC_ID="vpc-xxxxxx" # 실제 VPC ID 입력

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



