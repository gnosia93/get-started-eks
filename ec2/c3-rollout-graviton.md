
## 롤 아웃 ###

오토스케일링이 자동으로 Graviton 인스턴스를 생성하게 하려면 시작 템플릿(Launch Template)을 수정해야 한다.
* 새로운 시작 템플릿 버전 생성하여 AMI를 Graviton 으로 바꾸고, 인스턴스 타입을 c7g.2xlarge 변경한다.
* 오토스케일링 그룹의 시작 템플릿을 새 버전으로 업데이트 한다.
* 인스턴스 새로 고침(Instance Refresh) 기능을 활용하여 기존 x86 인스턴스들이 Graviton 인스턴스로 교체한다. (롤링 업그레이드)

![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-lt-1.png)

![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-lt-2.png)

### 1. 론치 템플릿 버전 생성 ###
기존 버전을 활용하여 신규 론치 템플릿 버전을 생성한다. 
```
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)
INSTANCE_TYPE="m7g.2xlarge"
LAUNCH_TEMPLATE="asg-lt-x86"
echo "AMI_ID: ${AMI_ID}, INSTANCE_TYPE: ${INSTANCE_TYPE}, LAUNCH_TEMPLATE: ${LAUNCH_TEMPLATE}"

aws ec2 create-launch-template-version --launch-template-name "${LAUNCH_TEMPLATE}" \
    --source-version 1 \
    --launch-template-data "{
        \"ImageId\": \"${AMI_ID}\", 
        \"InstanceType\": \"${INSTANCE_TYPE}\",
        \"MetadataOptions\": {
            \"InstanceMetadataTags\": \"enabled\"
        }
    }" \
    --query 'LaunchTemplateVersion.[LaunchTemplateName, VersionNumber]' \
    --output text
```
[결과]
```
asg-lt-x86      2
```

### 2. 오토스케일링 그룹(ASG) 업데이트 ###
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-lt-3.png)
오토 스케일링 그룹의 론치 템플릿을 새롭게 생성한 버전으로 수정한다

```
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name asg-x86 \
    --launch-template "LaunchTemplateName=asg-lt-x86,Version=2"
```

### 3. 인스턴스 새로 고침(Instance Refresh) 실행 ###
기존 x86 인스턴스들을 Graviton 인스턴스로 순차적으로 교체한다. MinHealthyPercentage 옵션을 통해 교체 중 유지할 최소 가동 인스턴스 비율을 조절할 수 있다. 
인스턴스 웜업은 EC2 Auto Scaling 그룹(ASG)에 새로 추가된 인스턴스가 모니터링 지표에 영향을 주기 전까지 대기하는 시간을 말한다.
```
aws autoscaling start-instance-refresh \
    --auto-scaling-group-name asg-x86 \
    --preferences '{"MinHealthyPercentage": 75, "InstanceWarmup": 60}'
```
[결과]
```
{
    "InstanceRefreshId": "15b739b8-5a34-4208-b06f-d9352d8dab19"
}
```

인스턴스 웜업은 새 인스턴스가 서비스 투입 전 애플리케이션 부팅과 초기화를 마칠 수 있도록 기다려 주는 유예 시간이다. 이를 너무 짧게 설정하면 준비되지 않은 인스턴스에 트래픽이 유입되어 5xx 서비스 에러가 발생하고, 부팅 시의 일시적으로 높은 부하가 지표에 반영되어 불필요한 과잉 스케일링이 유발할 수 있다. 또한 헬스 체크 실패로 인한 인스턴스 무한 재생성 루프에 빠질 수 있으며, 전체적인 배포 및 업데이트 프로세스가 지연되는 결과로 이어진다. 애플리케이션의 실제 구동 완료 시간을 측정해서 그 값을 조정할 필요가 있다.

### 4. 진행상태 확인 ###
```
aws autoscaling describe-instance-refreshes --auto-scaling-group-name asg-x86
```
[결과]
```
{
    "InstanceRefreshes": [
        {
            "InstanceRefreshId": "96a8b95b-fc03-41e4-9f62-269b1f0cd422",
            "AutoScalingGroupName": "vpc-stack-AutoScalingGroup-9xBagsFC6wAk",
            "Status": "InProgress",
            "StatusReason": "Waiting for instances to warm up before continuing. For example: i-0b0de24fe1d25b7e8 is warming up.",
            "StartTime": "2026-01-30T10:31:50+00:00",
            "PercentageComplete": 25,
            "InstancesToUpdate": 2,
            "Preferences": {
                "MinHealthyPercentage": 75,
                "InstanceWarmup": 60,
                "SkipMatching": false,
                "AutoRollback": false,
                "AlarmSpecification": {}
            }
        }
    ]
}
```
콘솔에서 ASG 의 Instance refresh 탭에서도 진행 상태를 확인할 수 있다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-inst-refresh.png)

## 롤백하기 ##
다음 챕터로 넘어가기 전에 인스턴스를 다시 x86 으로 변경한다.
```
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name asg-x86 \
    --launch-template "LaunchTemplateName=asg-lt-x86,Version=1"

aws autoscaling start-instance-refresh --auto-scaling-group-name asg-x86
```

