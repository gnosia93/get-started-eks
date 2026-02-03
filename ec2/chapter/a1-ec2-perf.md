```
#!/bin/bash

# 인스턴스 타입 목록 배열 선언
instance_types=(
  "c5.2xlarge"
  "c6g.2xlarge"
  "c6i.2xlarge"
  "c7g.2xlarge"
  "c7i.2xlarge"
  "c8g.2xlarge"
  "c8i.2xlarge"
)

# 루프 실행
for type in "${instance_types[@]}"; do
  echo "현재 인스턴스 타입: $type"
  # 여기에 AWS CLI 명령어 등을 추가할 수 있습니다.
done


AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)

INST_ID=$(aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
    --instance-type c7g.2xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data file://~/get-started-eks/ec2/cf/monte-carlo.sh \
    --metadata-options "InstanceMetadataTags=enabled" \
    --monitoring "Enabled=true" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=grav-nginx-perf}]' \
    --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$INST_ID"

aws ec2 describe-instances --instance-ids "$INST_ID" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text > GRAV_INST

cat GRAV_INST
```

c5.2xlarge c6g.2xlarge c6i.2xlarge c7g.2xlarge c7i.2xlarge c8g.2xlarge c8i.2xlarge 


## Reference ##
* https://docs.aws.amazon.com/ko_kr/ec2/latest/instancetypes/ec2-instance-regions.html
