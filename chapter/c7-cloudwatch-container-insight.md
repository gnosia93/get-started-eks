### 설치하기 ###
```
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CLUSTER_NAME="get-started-eks"
```
```
# 클러스터 이름과 리전 확인 후 실행
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name amazon-cloudwatch-observability \
  --region ${AWS_REGION}
```

```
kubectl get pods -n amazon-cloudwatch
```

### CloudWatch 콘솔에서 확인 ###
AWS CloudWatch 콘솔에 접속해서 왼쪽 메뉴에서 인사이트(Insights) -> Container Insights를 클릭한다.
상단 드롭다운에서 EKS Performance Monitoring을 선택하면 클러스터/노드/파드별 그래프가 나온다.
