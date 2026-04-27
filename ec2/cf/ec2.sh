export KEY_NAME= ...
export SG_ID= ...
export SUBNET_ID= ...

#!/bin/bash
launch_ec2() {
    local INST_TYPE=$1
    local TAG_NAME=$2
    local ARCH=$3

    AMI_ID=$(aws ssm get-parameters \
      --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$ARCH \
      --query "Parameters[0].Value" --output text)

    INST_ID=$(aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
        --instance-type "${INST_TYPE}" \
        --key-name "${KEY_NAME}" \
        --network-interfaces "AssociatePublicIpAddress=true,DeviceIndex=0,SubnetId=${SUBNET_ID},Groups=${SG_ID}" \
        --user-data file://monte-carlo.sh \
        --metadata-options "InstanceMetadataTags=enabled" \
        --monitoring "Enabled=true" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${TAG_NAME}}]" \
        --query 'Instances[0].InstanceId' --output text)

    INST_IP=$(aws ec2 describe-instances --instance-ids "$INST_ID" \
        --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

    if [[ $? -ne 0 || -z "$INST_IP" ]]; then
        echo "[$INST_TYPE] INST_IP 조회 실패 (INST_ID=$INST_ID)" >&2
        return 1
    fi

    echo "$INST_TYPE $TAG_NAME $INST_IP" >> ALL_INST_IPS
    echo "[$INST_TYPE] 생성 완료: $INST_IP"
}

instance_types=(
  "c5.2xlarge" "c6g.2xlarge" "c6i.2xlarge" "c7g.2xlarge" "c7i.2xlarge" 
  "c8g.2xlarge" "c8i.2xlarge"
)

for type in "${instance_types[@]}"; do
    family=$(echo $type | cut -d'.' -f1)
    if [[ $family == *"g"* ]]; then
        ARCH="arm64"
else
        ARCH="x86_64"
fi
    launch_ec2 "$type" "pt-$type" "$ARCH"
done
