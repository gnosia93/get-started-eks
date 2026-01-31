
## 롤 아웃 ###

오토스케일링이 자동으로 Graviton 인스턴스를 생성하게 하려면 시작 템플릿(Launch Template)을 수정해야 한다.
* 새로운 시작 템플릿 버전 생성하여 AMI를 Graviton 으로 바꾸고, 인스턴스 타입을 c7g.2xlarge 변경한다.
* 오토스케일링 그룹의 시작 템플릿을 새 버전으로 업데이트 한다.
* 인스턴스 새로 고침(Instance Refresh) 기능을 활용하여 기존 x86 인스턴스들이 Graviton 인스턴스로 교체한다. (롤링 업그레이드)

![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-lt-1.png)

![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-lt-2.png)

```
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)
INSTANCE_TYPE="m7g.2xlarge"
echo "AMI_ID: ${AMI_ID}, INSTANCE_TYPE: ${INSTANCE_TYPE}"

ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
    --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, 'vpc-stack-AutoScalingGroup-')].AutoScalingGroupName" \
    --output text)
LAUNCH_TEMPLATE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG_NAME}" \
  --query "AutoScalingGroups[].LaunchTemplate.LaunchTemplateName" \
  --output text)
echo "ASG_NAME: ${ASG_NAME}, LAUNCH_TEMPLATE: ${LAUNCH_TEMPLATE}"
```
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

#### 2. 오토스케일링 그룹(ASG) 업데이트 ####
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-launch-template-ver-list.png)
ASG가 방금 생성한 최신 버전($Latest) 또는 특정 버전의 템플릿을 사용하도록 설정한다.
```
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${ASG_NAME}" \
    --launch-template "LaunchTemplateName=${LAUNCH_TEMPLATE},Version=2"
```

#### 3. 인스턴스 새로 고침(Instance Refresh) 실행 ####
설정이 완료되면 기존 x86 인스턴스들을 새 ARM 인스턴스로 순차 교체한다. MinHealthyPercentage 옵션을 통해 교체 중 유지할 최소 가동 인스턴스 비율을 조절할 수 있다.
```
aws autoscaling start-instance-refresh \
    --auto-scaling-group-name "${ASG_NAME}" \
    --preferences '{"MinHealthyPercentage": 75, "InstanceWarmup": 300}'
```

#### 4. 진행상태 확인 ####
```
aws autoscaling describe-instance-refreshes --auto-scaling-group-name "${ASG_NAME}"
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
                "InstanceWarmup": 300,
                "SkipMatching": false,
                "AutoRollback": false,
                "AlarmSpecification": {}
            }
        }
    ]
}
```
콘솔에서 ASG 의 Instance refresh 탭에서도 진행 상태를 확인할 수 있다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-instance-refresh.png)
