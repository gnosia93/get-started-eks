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
