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








 * Pod
  * Service
  * Deployment
  * Daemon Set
  * SC/PV/PVC
  * ConfigMap
  * Secret
  * ClusterRole
  * Role
  * Service Account
  * OICD
  * Pod Identity
  * Ingress / Ingress GW
