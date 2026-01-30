## ALB 그라비톤 추가하기  ##
신규로 생성한 ARM 인스턴스를 기존 ALB의 타겟 그룹(Target Group)에 직접 등록하는 방법이다.
AWS 콘솔에서는 ALB의 타겟그룹 선택 → [Targets] 탭 → [Register targets] 클릭 → ARM 인스턴스를 선택 하면 된다.  

### #1.신규 그라비톤 인스턴스 생성 ###
아파치 웹서버를 서빙하는 그라비톤 인스턴스를 생성한다.
```
export KEY_NAME="aws-kp-2"

AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query "Parameters[0].Value" --output text)

SG_ID=$(aws cloudformation describe-stacks \
  --stack-name vpc-stack \
  --query "Stacks[0].Outputs[?OutputKey=='EC2SecurityGroupId'].OutputValue" \
  --output text)

SUBNET_ID=$(aws cloudformation describe-stack-resource \
  --stack-name vpc-stack \
  --logical-resource-id PublicSubnet1 \
  --query "StackResourceDetail.PhysicalResourceId" \
  --output text)

echo "AMI_ID: ${AMI_ID}, SG_ID: ${SG_ID}, Subnet: $SUBNET_ID"
```

아래 명령어로 graviton 신규 인스턴스를 2대 생성한다. 
```
aws ec2 run-instances --image-id ${AMI_ID} --count 2 \
    --instance-type c7g.2xlarge \
    --key-name ${KEY_NAME} \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SG_ID}" \
    --user-data "#\!/bin/bash
                 TOKEN=\$(curl -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 21600\")
                 LOCAL_IP=\$(curl -H \"X-aws-ec2-metadata-token: \$TOKEN\" -s http://169.254.169.254/latest/meta-data/local-ipv4)
                 HOSTNAME=\$(curl -H \"X-aws-ec2-metadata-token: \$TOKEN\" -s http://169.254.169.254)

                 # 패키지 설치 및 웹 페이지 생성
                 dnf update -y && dnf install -y httpd
                 systemctl start httpd && systemctl enable httpd

                 echo \"<h1>Hello from Graviton C7g</h1>
                       <p><b>Host:</b> \$HOSTNAME</p>
                       <p><b>Private IP:</b> \$LOCAL_IP</p>\" > /var/www/html/index.html" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Graviton-WebServer}]'
    --query 'Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress}' \
    --output table
```

### #2.AWS 콘솔 이용 ###

1. 좌측 Load Balencer 메뉴에서 [Listners and Rules] 탭을 선택한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-add-graviton-1.png)

2. [register target] 버튼을 클릭한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-add-graviton-2.png)

3. Register targets 에서 그라비톤을 한대 선택한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-add-graviton-3.png)

4.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-add-graviton-4.png)


### #3.AWS CLI 이용 ###

여기에서는 AWS CLI 명령어를 이용하여 그라비톤 인스턴스를 하나 만들고 기존 ALB 에 추가해 보도록 한다.  


