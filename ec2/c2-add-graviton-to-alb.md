## ALB 에 그라비톤 추가하기  ##
신규로 생성한 ARM 인스턴스를 기존 ALB의 타겟 그룹(Target Group)에 직접 등록하는 방법이다.
AWS 콘솔에서는 ALB의 타겟그룹 선택 → [Targets] 탭 → [Register targets] 클릭 → ARM 인스턴스를 선택 하면 된다.  

### 신규 그라비톤 인스턴스 생성 ###
아파치 웹서버를 서빙하는 그라비톤 인스턴스를 생성한다.
```
export KEY_NAME="aws-kp-2"
export STACK_NAME="graviton-mig-stack"

AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)

SG_ID=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query "Stacks[0].Outputs[?OutputKey=='EC2SecurityGroupId'].OutputValue" \
  --output text)

SUBNET_ID=$(aws cloudformation describe-stack-resource \
  --stack-name ${STACK_NAME} \
  --logical-resource-id PublicSubnet1 \
  --query "StackResourceDetail.PhysicalResourceId" \
  --output text)

echo "AMI_ID: ${AMI_ID}, SG_ID: ${SG_ID}, Subnet: $SUBNET_ID"
```

아래 명령어로 graviton 신규 인스턴스를 2대 생성한다. 
```
aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
    --instance-type c7g.xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=graviton-nginx}]' \
    --query 'Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress}' \
    --output table
```
[결과]
```
----------------------------------------------------------------
|                         RunInstances                         |
+----------------------+-------------+----------+--------------+
|          ID          |  PrivateIP  |  State   |    Type      |
+----------------------+-------------+----------+--------------+
|  i-06684829f38eaa18c |  10.0.1.102 |  pending |  c7g.xlarge  |
+----------------------+-------------+----------+--------------+
```

### ALB 에 등록 ###

<인스턴스 ID>를 위에서 생성한 인스턴스 ID 로 교체한 후 등록한다.
```
aws elbv2 register-targets --target-group-arn ${TG_ARN} --targets Id=<인스턴스 ID>
```

아래는 신규로 생성된 graviton 인스턴스를 ALB의 타겟그룹에 등록하는 명령어이다.
```
TG_ARN=$(aws elbv2 describe-target-groups --names tg-x86 --query 'TargetGroups[0].TargetGroupArn' --output text)
echo ${TG_ARN}

aws elbv2 register-targets --target-group-arn ${TG_ARN} --targets Id=i-06684829f38eaa18c
```

타겟 그룹에 등록된 인스턴스의 상태를 조회한다. 
```
aws elbv2 describe-target-health --target-group-arn ${TG_ARN} \
    --query 'TargetHealthDescriptions[].{InstanceID:Target.Id, Port:Target.Port, Status:TargetHealth.State, Description:TargetHealth.Description}' \
    --output table
```
