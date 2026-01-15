## Helm 의 이해 ##

쿠버네티스 애플리케이션을 헬름(Helm)으로 관리(패키징)해야 하는 이유는 단순히 '편해서'를 넘어 운영의 복잡성을 해결하기 위해서이다.

* 매니페스트 지옥 탈출 (템플릿화)    
기본적인 K8s 방식으로는 환경(개발, 테스트, 운영)마다 거의 비슷한 YAML 파일을 복사해서 수정해야 한다. Helm 은 템플릿을 사용해 하나의 차트(Chart)로 여러 환경에 대응할 수 있게 해준다. values.yaml 파일 설정만 바꾸면 CPU 할당량이나 이미지 태그 같은 설정값이 자동으로 주입된다. 

* 버전 관리와 손쉬운 롤백      
Helm은 배포할 때마다 릴리스(Release)라는 단위로 이력을 기록한다. 배포 중 문제가 생기면 helm rollback 명령어 한 번으로 이전 상태로 즉시 되돌릴 수 있어 서비스 장애 대응이 매우 빠르다. 

* 복잡한 의존성 해결           
애플리케이션이 DB나 캐시(Redis 등)를 필요로 할 때, 이를 일일이 설치할 필요가 없다. 헬름은 의존성 관리 기능을 통해 필요한 다른 차트들을 자동으로 가져와 함께 설치해 준다.

### 1. Helm 차트 생성 ###
```
cd ~
helm create flask-app
```
helm 에 의해서 만들어진 디렉토리는 다음과 같은 구조를 가지고 있다.
```
flask-app/
├── charts/                     # 이 차트가 의존하는 다른 차트들이 저장됨
├── Chart.yaml                  # 차트의 이름, 버전, 설명 등 메타데이터
├── values.yaml                 # ★ 가장 중요: 모든 설정값(이미지 주소, 리소스 등) 정의
└── templates/                  # 실제 쿠버네티스 리소스 템플릿 디렉토리
    ├── NOTES.txt               # 설치 후 사용자에게 보여줄 안내 메시지
    ├── _helpers.tpl            # 이름 공통화 등을 위한 템플릿 함수 정의
    ├── deployment.yaml         # ★ 앱 배포 본체
    ├── hpa.yaml                # 오토 스케일링 설정
    ├── httproute.yaml          # gateway 설정
    ├── ingress.yaml            # 도메인/외부 접속 설정
    ├── service.yaml            # 서비스 노출 설정
    ├── serviceaccount.yaml     # 서비스 노출 설정
    └── tests/                  # 설치 후 검증용 테스트 파일
```
* values.yaml: 배포할 때마다 바뀌는 값(ECR 주소, 태그, CPU/메모리)은 여기에 넣는다.
* templates/: 한번 만들어 두면 거의 바꿀 일이 없는 구조 파일들로, 배포 시 이 폴더의 파일들을 읽어 values.yaml의 값과 합쳐서 최종 YAML을 만들어 낸다.


### 2.Flask (flask-app.py) 도커라이징 ###

#### requirements.txt ####
```
cd ~/flask-app

cat <<EOF > requirements.txt
Flask==3.0.3
EOF
```

#### flask-app.py ####
```
cd ~/flask-app

cat <<EOF > flask-app.py
import platform
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/get', methods=['GET'])
def get_system_info():
    client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    
    server_info = {
        "client_ip": client_ip,
        "server_os": platform.system(),             # OS 명 (Windows, Linux 등)
        "server_os_release": platform.release(),    # OS 버전 상세
        "architecture": platform.architecture()[0], # 아키텍처 (64bit 등)
        "machine": platform.machine(),              # 프로세서 타입 (x86_64, arm64 등)
        "node_name": platform.node()                # 서버 호스트명
    }
    
    return jsonify(server_info)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8082, debug=True)
EOF
```

#### Dockerfile #### 
```
cd ~/flask-app

cat <<EOF > Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

EXPOSE 8082
CMD ["python", "flask-app.py"]
EOF
```
아래의 명령어로 flash-app 멀티 아키텍처 이미지를 빌드하여 ecr 에 푸시한다. 
```
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REPO_NAME="flask-app"
export ECR_URL=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}

aws ecr create-repository --repository-name flask-app --region ${AWS_REGION}
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

docker buildx create --name flask-builder --use
docker buildx inspect --bootstrap

docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${ECR_URL}:latest --push .
```

### 3. values.yaml 설정 ###
AWS 환경에 최적화된 ALB Ingress 설정을 포함한다.
```
cat <<EOF > values.yaml
replicaCount: 4

serviceAccount:
  create: false
  name: ""                 # 생략 가능하지만 구조상 그냥 둔다.

httpRoute:
  enabled: false

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80

image:
  repository: ${ECR_URL}
  tag: "latest"

service:
  name: flask-app
  type: ClusterIP
  port: 80                 # ALB가 접근할 서비스 포트
  targetPort: 8082         # 실제 Flask 앱의 포트

ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /get          # 502 Bad Gateway 방지용
    alb.ingress.kubernetes.io/healthcheck-port: "8082"        # 502 Bad Gateway 방지용
  hosts:
    - host: ""                             # 실제 도메인이 있다면 입력
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: flask-app
              port:
                number: 80                
EOF
```

### 4. 랜더링 및 배포하기 ###
설정한 차트가 정상적으로 렌더링(베이킹) 되는지 확인 한다.
```
helm install flask-app . --dry-run=client --debug
```
[결과]
```
level=DEBUG msg="Original chart version" version=""
level=DEBUG msg="Chart path" path=/home/ec2-user/flask-app
level=DEBUG msg="number of dependencies in the chart" dependencies=0
NAME: flask-app
LAST DEPLOYED: Thu Jan 15 03:44:04 2026
NAMESPACE: default
STATUS: pending-install
REVISION: 1
DESCRIPTION: Dry run complete
USER-SUPPLIED VALUES:
{}

COMPUTED VALUES:
...
```

flask-app 차트를 설치한다 (배포한다)
```
helm install flask-app .
```
[결과]
```
NAME: flask-app
LAST DEPLOYED: Thu Jan 15 03:45:34 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
NOTES:
1. Get the application URL by running these commands:
  http:///
```

#### (참고) 릴리즈 업그레이드 ####
values.yaml 파일을 수정한 후 릴리즈를 업데이트 할려면 ...
```
helm upgrade --install flask-app . -f values.yaml
```

### 생성된 오브젝트 확인 ###
레이블이 app.kubernetes.io/name=flask-app 오브젝트를 확인한다. 
```
kubectl get pod -l app.kubernetes.io/name=flask-app 
```
[결과]
```
NAME                         READY   STATUS    RESTARTS   AGE
flask-app-6ffb9b9b7f-5697k   1/1     Running   0          75s
flask-app-6ffb9b9b7f-bdwqt   1/1     Running   0          75s
flask-app-6ffb9b9b7f-m42vx   1/1     Running   0          75s
flask-app-6ffb9b9b7f-m8822   1/1     Running   0          75s
x86_64 $ kubectl get all -l app.kubernetes.io/name=flask-app 
NAME                             READY   STATUS    RESTARTS   AGE
pod/flask-app-6ffb9b9b7f-5697k   1/1     Running   0          79s
pod/flask-app-6ffb9b9b7f-bdwqt   1/1     Running   0          79s
pod/flask-app-6ffb9b9b7f-m42vx   1/1     Running   0          79s
pod/flask-app-6ffb9b9b7f-m8822   1/1     Running   0          79s

NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/flask-app   ClusterIP   172.20.70.172   <none>        80/TCP    79s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/flask-app   4/4     4            4           79s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/flask-app-6ffb9b9b7f   4         4         4       79s
```
인그레이스를 확인한다
```
kubectl get ingress -l app.kubernetes.io/name=flask-app 
```
[결과]
```
NAME        CLASS   HOSTS   ADDRESS                                                                      PORTS   AGE
flask-app   alb     *       k8s-default-flaskapp-4374173dc2-251488017.ap-northeast-2.elb.amazonaws.com   80      112s
```





