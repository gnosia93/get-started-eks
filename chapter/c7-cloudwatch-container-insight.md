### 설치하기 ###
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

### CloudWatch 콘솔에서 확인 ###
AWS CloudWatch 콘솔에 접속해서 왼쪽 메뉴에서 인사이트(Insights) -> Container Insights를 클릭한다.
상단 드롭다운에서 EKS Performance Monitoring을 선택하면 클러스터/노드/파드별 그래프가 나온다.
