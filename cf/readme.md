## 인프라 프로비저닝 ##




### VPC 생성 ###
```
cd ~/get-started-eks/cf
```

AWS 콘솔에서 KeyName 을 확인한후 아래 KEY_NAME 값을 수정한다. 
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
while true; do
  STATUS=$(aws cloudformation describe-stacks --stack-name vpc-stack --query "Stacks[0].StackStatus" --output text)
  echo "$(date +%H:%M:%S) - Current Status: $STATUS"
  
  if [[ "$STATUS" == *"COMPLETE"* ]] || [[ "$STATUS" == *"ROLLBACK"* ]] || [[ "$STATUS" == *"FAILED"* ]]; then
    echo "Stack creation finished with status: $STATUS"
    break
  fi
  sleep 10
done
```

생성후 결과를 확인한다.
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
