## 인프라 프로비저닝 ##




### VPC 생성 ###
```
cd get-started-eks/cf
```

```
export KEY_NAME="aws-kp-2"
aws cloudformation create-stack \
  --stack-name vpc-stack \
  --template-body file://vpc-stack.yaml \
  --parameters ParameterKey=KeyName,ParameterValue=${KEY_NAME} \
  --capabilities CAPABILITY_IAM
```

### 진행 상황 확인 (CLI) ###
```
aws cloudformation describe-stacks --stack-name vpc-stack --query "Stacks[0].StackStatus"
```

### ALB 주소 확인 (CLI) ###
```
aws cloudformation describe-stacks \
  --stack-name vpc-stack \
  --query "Stacks[0].Outputs[?OutputKey=='ALBURL'].OutputValue" \
  --output text
```
