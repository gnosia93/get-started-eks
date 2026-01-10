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

### 노드 Role 정책 추가 ###
클러스터의 노드 Role 리스트를 조회한다. 
```
NODE_ROLE_ARN_LIST=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups' --output text | tr '\t' '\n' \
| xargs -I {} aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name {} \
--query 'nodegroup.[nodeRole]' --output text)

echo ${NODE_ROLE_ARN_LIST}
```

CloudWatch 정책을 연결한다. 
```
for role_arn in $(echo "${NODE_ROLE_ARN_LIST}"); do
    # ARN에서 역할 이름(Role Name)만 추출
    ROLE_NAME=$(echo ${role_arn} | cut -d '/' -f2)
    
    echo "Applying policy to: ${ROLE_NAME}" 
    aws iam attach-role-policy --role-name ${ROLE_NAME} \
        --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
done
```

CloudWatchAgentServerPolicy 정책이 적용이 되었는지 확인한다. 
```
for role_arn in $(echo "${NODE_ROLE_ARN_LIST}"); do
  # ARN에서 역할 이름(Role Name)만 추출
  ROLE_NAME=$(echo ${role_arn} | cut -d '/' -f2)
  echo "${ROLE_NAME}"
  
  aws iam list-attached-role-policies --role-name ${ROLE_NAME} \
      --query 'AttachedPolicies[].PolicyName' --output table
done
```
[결과]
```
eksctl-get-started-eks-nodegroup-n-NodeInstanceRole-WOxSmW90nkkC
----------------------------------------
|       ListAttachedRolePolicies       |
+--------------------------------------+
|  CloudWatchAgentServerPolicy         |
|  AmazonSSMManagedInstanceCore        |
|  AmazonEKSWorkerNodePolicy           |
|  AmazonEC2ContainerRegistryPullOnly  |
|  AmazonEBSCSIDriverPolicy            |
+--------------------------------------+
eksctl-get-started-eks-nodegroup-n-NodeInstanceRole-BjOll4qrHHou
----------------------------------------
|       ListAttachedRolePolicies       |
+--------------------------------------+
|  CloudWatchAgentServerPolicy         |
|  AmazonSSMManagedInstanceCore        |
|  AmazonEKSWorkerNodePolicy           |
|  AmazonEC2ContainerRegistryPullOnly  |
|  AmazonEBSCSIDriverPolicy            |
+--------------------------------------+
```
* (주의) 카펜터 Role의 경우 별도로 존재하는 Role 이므로, 카펜터에도 CloudWatchAgentServerPolicy 추가시켜 줘야한다.  
* 카펜터 노드 Role eksctl-KarpenterNodeRole-${CLUSTER_NAME} 이다.

  
### CloudWatch 콘솔에서 확인 ###

#### 성능 메트릭 확인 ####
AWS CloudWatch 콘솔에 접속해서 왼쪽 메뉴에서 Infrastructure Monitoring 선택후 Container Insights 로 들어간다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/cloudwatch-container-insight.png)

#### 로그 확인 ####
AWS 콘솔의 CloudWatch > 로그 > 로그 그룹 메뉴에서 아래 경로를 검색한다.
* 애플리케이션 로그: /aws/containerinsights/Cluster_Name/application - 개별 컨테이너 및 파드에서 발생하는 표준 출력(stdout/stderr) 로그
* 호스트 로그: /aws/containerinsights/Cluster_Name/host - 노드 수준의 시스템 로그(/var/log/dmesg, /var/log/secure 등)
* 데이터플레인 로그: /aws/containerinsights/Cluster_Name/dataplane - EKS 데이터플레인 구성 요소(kubelet, kube-proxy, Docker/CRI runtime)의 로그
