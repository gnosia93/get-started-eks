
### # 인스턴스 생성 ###
```
export KEY_NAME="aws-kp-2"
export STACK_NAME="graviton-mig-stack"

SG_ID=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query "Stacks[0].Outputs[?OutputKey=='EC2SecurityGroupId'].OutputValue" \
  --output text)

SUBNET_ID=$(aws cloudformation describe-stack-resource \
  --stack-name ${STACK_NAME} \
  --logical-resource-id PublicSubnet1 \
  --query "StackResourceDetail.PhysicalResourceId" \
  --output text)

echo "SG_ID: ${SG_ID}, SUBNET_ID: ${SUBNET_ID}" 

#!/bin/bash
# 인스턴스 생성 함수 정의
launch_ec2() {
    local INST_TYPE=$1
    local TAG_NAME=$2
    local ARCH=$3  # x86_64 또는 arm64

    echo "[$INST_TYPE] AMI ID 조회 중..."
    AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$ARCH \
      --query "Parameters[0].Value" --output text)

    echo "[$INST_TYPE / $ARCH] 인스턴스 생성 시작..."
    INST_ID=$(aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
        --instance-type "${INST_TYPE}" \
        --key-name "${KEY_NAME}" \
        --subnet-id "${SUBNET_ID}" \
        --security-group-ids "${SG_ID}" \
        --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
        --metadata-options "InstanceMetadataTags=enabled" \
        --monitoring "Enabled=true" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${TAG_NAME}}]" \
        --query 'Instances[0].InstanceId' --output text)

    #echo "[$INST_TYPE] Running 상태 대기 중 ($INST_ID)..."
    #aws ec2 wait instance-running --instance-ids "$INST_ID"

    # 공인 IP 추출 및 파일 저장 (누적 기록)
    #PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INST_ID" \
    #    --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

    PRIVATE_IP=$(aws ec2 describe-instances --instance-ids "$INST_ID" \
        --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text)

    echo "$INST_TYPE $TAG_NAME $PRIVATE_IP" >> ALL_INST_IPS
    echo "[$INST_TYPE] 생성 완료: $PRIVATE_IP"
}

# 1. 인스턴스 타입 배열 정의
instance_types=( "c5.2xlarge" "c6g.2xlarge" "c6i.2xlarge" "c7g.2xlarge" "c7i.2xlarge" "c8g.2xlarge" "c8i.2xlarge" )

# 2. 루프 실행
for type in "${instance_types[@]}"; do

    family=$(echo $type | cut -d'.' -f1)
    if [[ $family == *"g"* ]]; then
        ARCH="arm64"
    else
        ARCH="x86_64"
    fi
    
    launch_ec2 "$type" "pt-$type" "$ARCH"
done

cat ALL_INST_IPS
```

### # 성능 테스트 ###

```
while read -r INST_TYPE HOSTNAME IP_ADDR; do    
    export BASE_URL="http://$IP_ADDR"
    echo "현재 실행 중: $INST_TYPE (BASE_URL: $BASE_URL)"
    cat k6-script.js | sed "s|#BASE_URL#|$BASE_URL|g" | k6 run --out "dashboard=report=$HOSTNAME.html" -
done < ALL_INST_IPS
```



## Reference ##
* https://docs.aws.amazon.com/ko_kr/ec2/latest/instancetypes/ec2-instance-regions.html
