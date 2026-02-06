## [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/) ##

AWS Load Balancer Controller는 Kubernetes 클러스터(주로 Amazon EKS) 내에서 AWS의 로드 밸런싱 서비스인 Elastic Load Balancing(ELB) 리소스를 자동으로 생성하고 관리해주는 컨트롤러이다. 쿠버네티스 사용자가 서비스나 인그레스(Ingress) 리소스를 생성하면, 이 컨트롤러가 이를 감지하여 실제 AWS 인프라 상에 필요한 로드 밸런서를 프로비저닝해 준다. 
쿠버네티스 매니페스트 설정에 따라 Application Load Balancer(ALB) 또는 Network Load Balancer(NLB)를 자동으로 생성한다.
* Ingress 생성 시: 계층 7(HTTP/HTTPS) 트래픽 처리를 위한 ALB를 생성.
* Service(type: LoadBalancer) 생성 시: 계층 4(TCP/UDP) 트래픽 처리를 위한 NLB를 생성.

### 1. OIDC 공급자 생성 ###
OIDC(OpenID Connect) 공급자는 쿠버네티스 파드가 AWS 리소스에 접근할 때 제시하는 '신분증을 발급하고 검증해 주는 기관' 이다. AWS 는 이를 통해 IRSA(IAM Roles for Service Accounts) 기능을 구현한다. 즉 EKS 클러스터가 AWS 서비스(ALB 등)를 제어할 수 있도록 신뢰 관계를 맺어주기 위해서는 OIDC 가 필요하다. EKS 클러스터를 만들면 고유한 OIDC 발급자 URL이 생성되는데, 
이 URL을 AWS IAM 서비스에 등록하는 과정이 바로 eksctl utils associate-iam-oidc-provider 이다. 
이제 파드가 AWS 기능을 쓰려 할 때, IAM은 등록된 OIDC 공급자를 통해 "이 파드가 정말 해당 클러스터 소속인가"를 체크하게 되고, 체크가 성공하면 권한을 주게 된다.
```
OIDC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
echo "Cluster OIDC ID: $OIDC_ID"

# IAM에 해당 ID를 가진 OIDC 공급자가 있는지 검색
if aws iam list-open-id-connect-providers | grep -q "$OIDC_ID"; then
  echo "✅ 결과: OIDC 공급자가 이미 IAM에 등록되어 있습니다."
else
  echo "❌ 결과: OIDC 공급자가 없습니다. 등록이 필요합니다."
fi
```
OIDC 공급자가 없는 경우 등록해 준다.
```
eksctl utils associate-iam-oidc-provider --region ${AWS_REGION} \
    --cluster ${CLUSTER_NAME} --approve
```

### 2. IAM Policy 및 Role 생성 ###
컨트롤러가 ALB를 만들고 수정할 수 있는 권한을 부여해야 한다. AWS 공식 IAM 정책 JSON을 다운로드하여 IAM 정책을 만든 뒤, EKS의 서비스 어카운트인 aws-load-balancer-controller 와 연결한다.
```
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.17.0/docs/install/iam_policy.json
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

eksctl create iamserviceaccount \
--cluster=${CLUSTER_NAME} \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--region ${AWS_REGION} \
--approve
```

### 3. AWS Load Balancer Controller 설치 ###
이 컨트롤러가 실행 중이어야 Ingress를 배포했을 때 이를 감지하고 ALB를 생성해 준다.
```
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl get deployment -n kube-system aws-load-balancer-controller
```
설치된 helm 리스트를 조회한다.
```
helm list -A
```
[결과]
```
NAME                            NAMESPACE                       REVISION        UPDATED                                 STATUS          CHART                                      APP VERSION
aws-load-balancer-controller    kube-system                     1               2026-01-11 14:58:42.412230135 +0000 UTC deployed        aws-load-balancer-controller-1.17.1        v2.17.1    
karpenter                       karpenter                       1               2026-01-11 08:31:41.379368095 +0000 UTC deployed        karpenter-1.8.1                            1.8.1      
```
아래 명령어로 AWS Load Balancer Controller 의 로그를 확인할 수 있다. 
```
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

### 4. 서브넷 태깅 (매우 중요!) ###
ELB가 생성될 서브넷을 결정하려면 VPC 서브넷에 특정 태그가 있어야 한다. 본 워크샵에서는 Terraform으로 VPC를 생성할 때 이 태깅 작업이 자동으로 수행되도록 설정되어 있다.

#### Public 서브넷: kubernetes.io/role/elb = 1 ####
```
aws ec2 describe-subnets \
    --filters "Name=tag-key,Values=kubernetes.io/role/elb" \
              "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].{SubnetId:SubnetId, Name:Tags[?Key==`Name`].Value | [0]}' \
    --output table
```
[결과]
```
--------------------------------------------------
|                 DescribeSubnets                |
+-------------------+----------------------------+
|       Name        |         SubnetId           |
+-------------------+----------------------------+
|  GSE-pub-subnet-3 |  subnet-022b147d9c22af883  |
|  GSE-pub-subnet-1 |  subnet-0dc60f30d9c7636e0  |
|  GSE-pub-subnet-2 |  subnet-0c9589e57ac38a4a0  |
|  GSE-pub-subnet-4 |  subnet-0db8fad220d630d4f  |
+-------------------+----------------------------+
```
#### Private 서브넷: kubernetes.io/role/internal-elb = 1 ####
```
aws ec2 describe-subnets \
    --filters "Name=tag-key,Values=kubernetes.io/role/internal-elb" \
              "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].{SubnetId:SubnetId, Name:Tags[?Key==`Name`].Value | [0]}' \
    --output table
```
```
---------------------------------------------------
|                 DescribeSubnets                 |
+--------------------+----------------------------+
|        Name        |         SubnetId           |
+--------------------+----------------------------+
|  GSE-priv-subnet-1 |  subnet-056f17f24a18f7075  |
|  GSE-priv-subnet-4 |  subnet-08303b9489542c242  |
|  GSE-priv-subnet-3 |  subnet-0ce0ae2c5247ec02e  |
|  GSE-priv-subnet-2 |  subnet-006e01c1a005b5aa3  |
+--------------------+----------------------------+
```

## Ingress 생성해 보기 ##

```
cat <<EOF | kubectl apply -f - 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 4
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  # 인그레스가 인스턴스 모드(target-type: instance) 인 경우 Service 의 type 은 NodePort 로 설정해야 한다.
  # 인스턴스 모드에서는 ALB → Node (NodePort) → iptables/proxy → Pod 트레픽이 흘려간다.
  # 이 예제에서 사용하는 IP 모드(target-type: ip)는 Service 에 ClusterIP 또는 NodePort 모두 설정이 가능하지만, ClusterIP 로 설정하도록 한다.
  # IP 모드에서는 트래픽은 ALB → Pod 로 전달된다.
  type: ClusterIP 
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    # AWS Load Balancer Controller가 ALB를 생성하도록 지정합니다.
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb                     # 설치된 컨트롤러 클래스 이름을 지정하세요.
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
EOF
```
생성된 인그레스를 조회 한다.
```
kubectl get ingress nginx-ingress
NAME            CLASS   HOSTS   ADDRESS                                                                       PORTS   AGE
nginx-ingress   alb     *       k8s-default-nginxing-c0a6494b10-1037751053.ap-northeast-2.elb.amazonaws.com   80      74s
```






