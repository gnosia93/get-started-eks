### VPC 생성 ###
```
cd ~/get-started-eks/ec2/cf
```

AWS 콘솔에서 KeyName 을 확인한후 아래 KEY_NAME 값을 수정한다. 
```
export KEY_NAME="aws-kp-2"

aws cloudformation create-stack --stack-name graviton-mig-stack \
  --template-body file://vpc-stack.yaml \
  --parameters ParameterKey=UserDataScript,ParameterValue="$(cat monte-carlo.sh)" \
  --parameters ParameterKey=KeyName,ParameterValue=${KEY_NAME} \
  --capabilities CAPABILITY_IAM
```
[결과]
```
{
    "StackId": "arn:aws:cloudformation:ap-northeast-2:499514681453:stack/graviton-mig-stack/fa631390-fdf4-11f0-9414-06321de6782d"
}
```

### 진행 상황 확인 ###
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


### VPC 삭제 ###
```
aws cloudformation delete-stack --stack-name graviton-mig-stack
```

### Output 확인 ###
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
|  ALBURL              |  my-alb-2056508941.ap-northeast-2.elb.amazonaws.com                                                  |
|  ALBSecurityGroupId  |  sg-0b56776825bf99064                                                                                |
|  LaunchTemplateName  |  lt-02a98372ddefa70ff                                                                                |
|  EC2SecurityGroupId  |  sg-0a1d559e8657c4d62                                                                                |
|  AutoScalingGroupName|  asg-x86                                                                                             |
|  ALBName             |  arn:aws:elasticloadbalancing:ap-northeast-2:499514681453:loadbalancer/app/my-alb/e883d566e0e6812e   |
|  TargetGroupName     |  tg-x86                                                                                              |
+----------------------+------------------------------------------------------------------------------------------------------+```
```

### ALB DNS 룩업 ###
```
nslookup my-alb-2056508941.ap-northeast-2.elb.amazonaws.com  
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
