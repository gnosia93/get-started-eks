


```
aws cloudformation create-stack \
  --stack-name my-eks-dev-stack \
  --template-body file://template.yaml \
  --parameters \
    ParameterKey=AllowedIpCidrs,ParameterValue="211.234.56.78/32" \
    ParameterKey=KeyName,ParameterValue="aws-kp-2" \
    ParameterKey=ClusterName,ParameterValue="get-started-eks" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-2
```
