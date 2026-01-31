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

아래 명령어로 graviton 신규 인스턴스를 1대 생성한다. 
```
GRAVITON_INST=$(aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
    --instance-type c7g.2xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
    --metadata-options "InstanceMetadataTags=enabled" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=grav-nginx}]' \
    --query 'Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress}' \
    --output table)
echo ${GRAVITON_INST}
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
아래는 신규로 생성된 graviton 인스턴스를 ALB의 타겟그룹에 등록하는 명령어이다.
```
TG_ARN=$(aws elbv2 describe-target-groups --names tg-x86 --query 'TargetGroups[0].TargetGroupArn' --output text)
INSTANCE_ID=$(echo "${GRAVITON_INST}" | grep "i-" | awk -F'|' '{print $2}' | xargs)
echo "TG_ARN: ${TG_ARN}, GRAVITON_INST_ID: ${INSTANCE_ID}"

aws elbv2 register-targets --target-group-arn ${TG_ARN} --targets Id=${INSTANCE_ID}
```

타겟 그룹에 등록된 인스턴스의 상태를 조회한다. Status 값이 initial 이 되면 웹브라우저를 이용해서 ALB 의 DNS 주소를 조회한다. 
```
aws elbv2 describe-target-health --target-group-arn ${TG_ARN} \
    --query 'TargetHealthDescriptions[].{InstanceID:Target.Id, Port:Target.Port, Status:TargetHealth.State, Description:TargetHealth.Description}' \
    --output table
```
[결과]
```
----------------------------------------------------------------------------------
|                              DescribeTargetHealth                              |
+-------------------------------------+-----------------------+-------+----------+
|             Description             |      InstanceID       | Port  | Status   |
+-------------------------------------+-----------------------+-------+----------+
|  None                               |  i-0d5fdf88c0d3b8f4a  |  80   |  healthy |
|  None                               |  i-0fc999a4f3323045e  |  80   |  healthy |
|  Target registration is in progress |  i-0080fb3a7a23b59a8  |  80   |  initial |
+-------------------------------------+-----------------------+-------+----------+
```
그라비톤 인스턴스가 ALB 에 조인하였다.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-graviton-join.png)



