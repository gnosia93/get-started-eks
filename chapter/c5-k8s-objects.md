## K8S 오브젝트 ##
### Pod ###
쿠버네티스의 파드(Pod)란 하나 이상의 컨테이너를 논리적으로 묶어 함께 실행하고 관리하는 배포 단위로, 동일한 파드 내 컨테이너들은 IP 주소와 포트, 저장 공간을 공유한다. 쿠버네티스에서 파드는 애플리케이션을 실행하는 가장 작은 단위로서 실행에 필요한 설정과 환경 정보를 모두 포함하고 있으며, 클러스터 내 어떤 노드에 배치할지 결정하는 스케줄링의 가장 근본적인 기준이 된다.
```
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: web
spec:
  containers:
  - name: nginx-container
    image: nginx:latest
``` 
### Deployment ###
쿠버네티스의 디플로이먼트(Deployment)란 파드의 개수와 상태를 선언적으로 정의하여 관리하는 컨트롤러로, 서비스에 필요한 파드들을 클러스터에 안정적으로 배포하는 역할을 한다. 사용자가 애플리케이션의 복제본(Replicas) 개수를 지정하면 디플로이먼트는 이를 실시간으로 감시하며 파드의 장애나 노드 결함 시에도 항상 지정된 개수를 유지한다. 또한, 서비스 중단 없이 애플리케이션 버전을 업데이트하는 롤링 업데이트와 문제 발생 시 이전 버전으로 즉시 되돌리는 롤백 기능을 제공하는 운영 관리의 핵심 단위이다.
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy
spec:
  replicas: 3           # 파드 3개 유지
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:latest
```
### Service ###
```
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web           # 'app: web' 라벨을 가진 파드들로 연결
  ports:
  - protocol: TCP
    port: 80           # 서비스가 받는 포트
    targetPort: 80     # 파드의 포트
```
### Ingress ###
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  rules:
  - host: "my-app.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```
### ConfigMap ###
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  WELCOME_MSG: "Hello, Kubernetes!"
```
### Secret ###
```
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  db-password: dXNlcjEyMw== # 'user123'을 Base64로 변환한 값
```
### Service Account ###
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot
```

## 풀 스택 Manifest ##
[manifest.yaml]
```
# ---------------------------------------------------------
# 1. Configuration & Security (설정 및 보안)
# ---------------------------------------------------------
apiVersion: v1
kind: ConfigMap
metadata:
  name: pro-app-config
data:
  LOG_LEVEL: "debug"
  DB_URL: "jdbc:mysql://db-svc:3306/main"
---
apiVersion: v1
kind: Secret
metadata:
  name: pro-app-secret
type: Opaque
data:
  # 'admin-password'를 base64 인코딩한 값
  API_KEY: "YWRtaW4tcGFzc3dvcmQ="
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pro-app-sa
# API 접근이 필요 없는 경우 false로 설정하여 보안 하드닝
automountServiceAccountToken: true

---
# ---------------------------------------------------------
# 2. Workload (애플리케이션 배포)
# ---------------------------------------------------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pro-app-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pro-service
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: pro-service
    spec:
      serviceAccountName: pro-app-sa
      containers:
      - name: main-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: pro-app-config
        - secretRef:
            name: pro-app-secret
        resources:
          limits:
            cpu: "200m"
            memory: "256Mi"
          requests:
            cpu: "100m"
            memory: "128Mi"
        # 운영 안정성을 위한 Probe 설정
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10

---
# ---------------------------------------------------------
# 3. Networking (트래픽 제어)
# ---------------------------------------------------------
apiVersion: v1
kind: Service
metadata:
  name: pro-app-svc
spec:
  type: ClusterIP  # Ingress를 사용할 것이므로 내부용 IP만 할당
  selector:
    app: pro-service
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pro-app-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    # 실제 환경에서는 Cert-Manager를 연동하여 SSL 적용 가능
spec:
  rules:
  - host: "app.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pro-app-svc
            port:
              number: 80
```
```
kubectl apply -f manifest.yaml
kubectl get all
kubectl exec -it <pod-name> -- env | grep LOG_LEVEL
```


