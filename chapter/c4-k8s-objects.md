## nginx 실행해 보기 ##
```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 2 # 2개의 Nginx 파드를 실행합니다.
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      # 만약 기존 노드에 리소스가 부족하다면, 
      # 이 요청량 때문에 Karpenter가 새 노드를 띄울 수 있습니다.
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "1000m"
          limits:
            memory: "256Mi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  type: LoadBalancer # AWS CLB(Classic Load Balancer)를 자동으로 생성합니다.
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF
```

nginx 서비스를 조회한 후, 웹브라우저로 접속해 본다. 
```
kubectl get svc nginx
```
[결과]
```
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)        AGE
nginx        LoadBalancer   172.20.151.112   a8bef1d582261479aa1eaffae26de2a0-2081456608.us-west-2.elb.amazonaws.com   80:30299/TCP   10s
```

## Ingress 사용해 보기 ##
EKS 에서 서비스 타입을 LoadBalancer 대신 Ingress로 변경하려면, 서비스 타입을 NodePort 또는 ClusterIP로 바꾸고 Ingress 리소스를 추가해야 한다.
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
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
  name: nginx-service
spec:
  selector:
    app: nginx
  # 인드레스가 인스턴스 모드(target-type: instance) 인 경우  Service 의 type 은 NodePort 로 설정해야 한다.
  # 이경우 트래픽은 ALB → Node (NodePort) → iptables/proxy → Pod 흘려간다.
  # 이 예제에서 사용하는 IP 모드(target-type: ip)는 ClusterIP 또는 NodePort 모두 설정이 가능하지만, ClusterIP 로 설정하도록 한다.
  # 이경우 트래픽은 ALB → Pod 로 전달된다.
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
  ingressClassName: alb # 설치된 컨트롤러 클래스 이름을 지정하세요.
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```
이렇게 실행해 보고 상태를 관찰한다.. 그리고 AWC LBC 설명.

### AWS Load Balancer Controller ###
eks 에서 Ingress(ALB)를 사용하려면 단순히 yaml 로 요청하는 것으로는 부족하고, 트래픽을 받아줄 실제 ALB를 생성해 줄 '엔진'이 필요하다. 바로 AWS Load Balancer Controller를 설치하는 것이다.

#### 1. OIDC 공급자 생성 ####
EKS 클러스터가 AWS 서비스(ALB 등)를 제어할 수 있도록 신뢰 관계를 맺어주는 과정입니다.
```
방법: eksctl utils associate-iam-oidc-provider --cluster <클러스터명> --approve
```
#### 2. IAM Policy 및 Role 생성 ####
컨트롤러가 사용자 대신 ALB를 만들고 수정할 수 있는 권한을 부여해야 합니다.
AWS 공식 IAM 정책 JSON을 다운로드하여 IAM 정책을 만든 뒤, EKS의 ServiceAccount와 연결합니다.

#### 3. AWS Load Balancer Controller 설치 ####
보통 Helm을 사용하여 클러스터에 설치합니다.
이 컨트롤러가 실행 중이어야 내가 kind: Ingress를 배포했을 때 이를 감지하고 실제 AWS 콘솔에 ALB를 생성합니다.

#### 4. 서브넷 태깅 (매우 중요!) ####
ALB가 어떤 서브넷에 생성되어야 할지 자동으로 찾을 수 있도록 VPC 서브넷에 태그를 달아야 한다.
* 공용(Public) 서브넷: kubernetes.io/role/elb = 1
* 사설(Private) 서브넷: kubernetes.io/role/internal-elb = 1
```
aws ec2 describe-subnets \
    --filters "Name=tag-key,Values=kubernetes.io/role/elb" \
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


