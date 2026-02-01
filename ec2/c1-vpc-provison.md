## 리소스 생성 ##

### VPC 생성하기 ###
```
cd ~/get-started-eks/ec2/cf
```

AWS 콘솔에서 KeyName 을 확인한후 아래 KEY_NAME 값을 수정한다. 
```
export KEY_NAME="aws-kp-2"
export MY_IP=$(curl -s http://checkip.amazonaws.com)/32
echo "key_name: ${KEY_NAME}, my_ip: ${MY_IP} ..."

aws cloudformation create-stack --stack-name graviton-mig-stack \
  --template-body file://vpc-stack.yaml \
  --parameters "$(jq -n \
    --arg script "$(cat monte-carlo.sh)" \
    --arg key "$KEY_NAME" \
    --arg ip "$MY_IP" \
    '[
      {ParameterKey: "UserDataScript", ParameterValue: $script},
      {ParameterKey: "KeyName", ParameterValue: $key},
      {ParameterKey: "MyIP", ParameterValue: $ip}
    ]')" \
  --capabilities CAPABILITY_IAM
```
[결과]
```
{
    "StackId": "arn:aws:cloudformation:ap-northeast-2:499514681453:stack/graviton-mig-stack/fa631390-fdf4-11f0-9414-06321de6782d"
}
```

### 진행 상태 확인 ###
```
while true; do
  STATUS=$(aws cloudformation describe-stacks --stack-name graviton-mig-stack --query "Stacks[0].StackStatus" --output text)
  echo "$(date +%H:%M:%S) - Current Status: $STATUS"
  
  if [[ "$STATUS" == *"COMPLETE"* ]] || [[ "$STATUS" == *"ROLLBACK"* ]] || [[ "$STATUS" == *"FAILED"* ]]; then
    echo "Stack creation finished with status: $STATUS"
    break
  fi
  sleep 10
done
```
[결과]
```
11:43:41 - Current Status: CREATE_IN_PROGRESS
11:43:53 - Current Status: CREATE_IN_PROGRESS
11:44:04 - Current Status: CREATE_IN_PROGRESS
11:44:15 - Current Status: CREATE_IN_PROGRESS
11:44:27 - Current Status: CREATE_IN_PROGRESS
11:44:38 - Current Status: CREATE_IN_PROGRESS
11:44:50 - Current Status: CREATE_IN_PROGRESS
11:45:02 - Current Status: CREATE_IN_PROGRESS
11:45:13 - Current Status: CREATE_IN_PROGRESS
11:45:24 - Current Status: CREATE_IN_PROGRESS
11:45:36 - Current Status: CREATE_IN_PROGRESS
11:45:48 - Current Status: CREATE_IN_PROGRESS
11:45:59 - Current Status: CREATE_IN_PROGRESS
11:46:11 - Current Status: CREATE_COMPLETE
Stack creation finished with status: CREATE_COMPLETE
```

### 생성 결과 확인 ###
```
aws cloudformation describe-stacks --stack-name graviton-mig-stack \
  --query "Stacks[0].Outputs[][OutputKey, OutputValue]" \
  --output table
```
[결과]
```
-------------------------------------------------------------------------------------------------------------------------------
|                                                       DescribeStacks                                                        |
+----------------------+------------------------------------------------------------------------------------------------------+
|  ALBURL              |  my-alb-969615135.ap-northeast-2.elb.amazonaws.com                                                   |
|  ALBSecurityGroupId  |  sg-0d384816d2ab31862                                                                                |
|  LaunchTemplateName  |  asg-lt-x86                                                                                          |
|  EC2SecurityGroupId  |  sg-0cb1c014a6d3f9790                                                                                |
|  AutoScalingGroupName|  asg-x86                                                                                             |
|  BastionHostDNS      |  ec2-43-201-45-27.ap-northeast-2.compute.amazonaws.com                                               |
|  BastionHostIP       |  43.201.45.27                                                                                        |
|  ALBName             |  arn:aws:elasticloadbalancing:ap-northeast-2:499514681453:loadbalancer/app/my-alb/99cb9be3a70dff49   |
|  TargetGroupName     |  tg-x86                                                                                              |
+----------------------+------------------------------------------------------------------------------------------------------+
```

### ALB DNS 룩업 ###
```
nslookup my-alb-969615135.ap-northeast-2.elb.amazonaws.com  
```
[결과]
```
Server:		61.41.153.2
Address:	61.41.153.2#53

Non-authoritative answer:
Name:	my-alb-2056508941.ap-northeast-2.elb.amazonaws.com
Address: 15.165.130.95
Name:	my-alb-2056508941.ap-northeast-2.elb.amazonaws.com
Address: 43.202.144.25
```
ALB 주소의 DNS 가 위와 같이 2개 등록될 때 까지 기다린다. ALB 의 경우 생성 후, 정상적으로 동작하기 까지 시간이 필요하다 

```
curl my-alb-969615135.ap-northeast-2.elb.amazonaws.com   
```
DNS 등록이 완료되면 curl 로 페이지가 제대로 뜨는지 확인한다.

### vscode 베스천 호스트 접속 ###
http://ec2-43-201-45-27.ap-northeast-2.compute.amazonaws.com:8080 포트를 접속한다.



## 리소스 삭제 ##
```
aws ec2 delete-launch-template --launch-template-name asg-lt-arm
aws elbv2 delete-load-balancer --load-balancer-arn $(aws elbv2 describe-load-balancers --names my-alb --query "LoadBalancers[0].LoadBalancerArn" --output text)
TG_ARN=$(aws elbv2 describe-target-groups --names tg-arm --query "TargetGroups[0].TargetGroupArn" --output text | xargs)
aws elbv2 delete-target-group --target-group-arn $TG_ARN
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name asg-arm --force-delete

aws cloudformation delete-stack --stack-name graviton-mig-stack
```

