### 애드온 설치하기 ###
```
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CLUSTER_NAME="get-started-eks"
```
애드온을 설치한다.
```
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name amazon-cloudwatch-observability \
  --region ${AWS_REGION}
```
ACTIVE 임을 확인한다.
```
aws eks describe-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name amazon-cloudwatch-observability \
  --region ${AWS_REGION} \
  --query "addon.status" --output text
```

관련된 파드를 조회한다.
```
kubectl get pods -n amazon-cloudwatch
```
[결과]
```
NAME                                                              READY   STATUS    RESTARTS   AGE
amazon-cloudwatch-observability-controller-manager-6868dd9fx5sh   1/1     Running   0          109s
cloudwatch-agent-7ktgj                                            1/1     Running   0          106s
cloudwatch-agent-bghhq                                            1/1     Running   0          106s
cloudwatch-agent-spj6g                                            1/1     Running   0          106s
cloudwatch-agent-w22v9                                            1/1     Running   0          106s
fluent-bit-87whs                                                  1/1     Running   0          110s
fluent-bit-b2687                                                  1/1     Running   0          110s
fluent-bit-cl586                                                  1/1     Running   0          110s
fluent-bit-xd6rs                                                  1/1     Running   0          110s
```
매트릭을 수집하는 cloudwatch-agent 와 컨테이너 로그를 수집하는 fluent-bit 가 설치되었다.

```
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent
```
에이전트의 로그를 확인한다.

### Role 추가 ###
```
# 노드 그룹의 IAM 역할 이름 확인
MY_ROLE_NAME=$(aws eks describe-nodegroup \
    --cluster-name your-cluster-name \
    --nodegroup-name your-nodegroup-name \
    --query 'nodegroup.nodeRole' \
    --output text | awk -F'/' '{print $NF}')

# CloudWatch 정책 연결
aws iam attach-role-policy \
    --role-name $MY_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### CloudWatch 콘솔에서 확인 ###
AWS CloudWatch 콘솔에 접속해서 왼쪽 메뉴에서 Infrastructure Monitoring 선택후 Container Insights 로 들어간다.
