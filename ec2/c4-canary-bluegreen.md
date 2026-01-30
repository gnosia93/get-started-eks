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
만들어진 타겟 그룹을 ASG 에 연결한다.
```
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${ASG_NAME}" \
    --target-group-arns "${TG_ARN}"
```


#### 2. 리스너에 타켓그룹 등록 ####




#### 3. 트래픽 비율조정 ####
```
# 변수 설정
LISTENER_ARN="arn:aws:elasticloadbalancing:..." # 기존 리스너 ARN
OLD_TG_ARN="arn:aws:elasticloadbalancing:..."   # 기존 타겟 그룹 ARN
NEW_TG_ARN="arn:aws:elasticloadbalancing:..."   # 신규 Graviton 타겟 그룹 ARN

# 트래픽 비중 조정 (기존 80 : 신규 20)
aws elbv2 modify-listener \
    --listener-arn "${LISTENER_ARN}" \
    --default-actions "[
        {
            \"Type\": \"forward\",
            \"ForwardConfig\": {
                \"TargetGroups\": [
                    { \"TargetGroupArn\": \"${OLD_TG_ARN}\", \"Weight\": 80 },
                    { \"TargetGroupArn\": \"${NEW_TG_ARN}\", \"Weight\": 20 }
                ],
                \"TargetGroupStickinessConfig\": {
                    \"Enabled\": false
                }
            }
        }
    ]"
```


### 참고 - Graviton 용으로 ASG 를 별도로 만드는 이유 ###
* 바이너리 호환성: ASG는 하나의 '시작 템플릿'만 사용하는데, 템플릿에 arm64(Graviton) AMI를 넣으면 ASG가 띄우는 모든 인스턴스가 Graviton이 된다.
* 동시 공급의 문제: 하나의 ASG에 TG-A, TG-B를 연결하면, ASG가 생성하는 모든 인스턴스가 두 타겟 그룹에 동시에 등록된다. 



