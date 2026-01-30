
## 롤 아웃 ###
오토스케일링이 자동으로 ARM 인스턴스를 생성하게 하려면 시작 템플릿(Launch Template)을 업데이트해야 한다.
* 새로운 시작 템플릿 버전 생성 - AMI를 ARM용(Graviton)으로 바꾸고, 인스턴스 유형을 ARM 계열(예: t4g, c7g 등)로 변경.
* 오토스케일링 그룹의 시작 템플릿을 방금 만든 새 버전으로 업데이트.
* 인스턴스 새로 고침(Instance Refresh) 기능을 사용하면 기존 x86 인스턴스들이 순차적으로 종료되고 새 ARM 인스턴스로 자동 교체.




### AWS CLI 활용 ###

#### 1. 신규 론치 템플릿 버전 생성 ####
EC2 콘솔의 좌측 메뉴 최하단의 
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-launch-template.png)
Versions 탭을 클릭하여 템플릿 버전을 확인한다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/asg-launch-template-ver.png)
기존 템플릿을 기반으로 ARM용 AMI ID와 인스턴스 유형을 업데이트하여 새 버전을 만든다.
```
aws ec2 create-launch-template-version \
    --launch-template-name "YourTemplateName" \
    --source-version 1 \
    --launch-template-data '{
        "ImageId": "ami-xxxxxxxxxxxxxxxxx", 
        "InstanceType": "t4g.micro"
    }'
```

#### 2. 오토스케일링 그룹(ASG) 업데이트 ####
ASG가 방금 생성한 최신 버전($Latest) 또는 특정 버전의 템플릿을 사용하도록 설정한다.
```
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
    --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, 'vpc-stack-AutoScalingGroup-')].AutoScalingGroupName" \
    --output text)
echo ${ASG_NAME}

aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${ASG_NAME}" \
    --launch-template "LaunchTemplateName=YourTemplateName,Version='$Latest'"
```

#### 3. 인스턴스 새로 고침(Instance Refresh) 실행 ####
설정이 완료되면 기존 x86 인스턴스들을 새 ARM 인스턴스로 순차 교체한다. MinHealthyPercentage 옵션을 통해 교체 중 유지할 최소 가동 인스턴스 비율을 조절할 수 있다.
```
aws autoscaling start-instance-refresh \
    --auto-scaling-group-name "YourASGName" \
    --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 300}'
```

#### 4. 진행상태 확인 ####
```
aws autoscaling describe-instance-refreshes --auto-scaling-group-name "YourASGName"
```
