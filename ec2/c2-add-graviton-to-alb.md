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
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=graviton-nginx}]'
    --query 'Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress}' \
    --output table
```

### ALB 에 등록 ###

여기에서는 AWS CLI 명령어를 이용하여 그라비톤 인스턴스를 하나 만들고 기존 ALB 에 추가해 보도록 한다.  
```
# 1. 실행 중인 인스턴스 ID 가져오기
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=Graviton-WebServer" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" --output text)

# 2. 대상 그룹(Target Group)에 등록
# TARGET_GROUP_ARN 부분을 본인의 대상 그룹 ARN으로 변경하세요.
aws elbv2 register-targets \
    --target-group-arn "arn:aws:elasticloadbalancing:region:account:targetgroup/name/id" \
    --targets $(echo $INSTANCE_IDS | sed 's/i-/Id=i-/g')
```


