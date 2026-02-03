```
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


## Reference ##
* https://docs.aws.amazon.com/ko_kr/ec2/latest/instancetypes/ec2-instance-regions.html
