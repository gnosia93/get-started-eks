<< 아래 내용은 테스트 및 수정이 필요하다 >>

## Helm 의 이해 ##

쿠버네티스 애플리케이션을 헬름(Helm)으로 관리(패키징)해야 하는 이유는 단순히 '편해서'를 넘어 운영의 복잡성을 해결하기 위해서이다.

* 매니페스트 지옥 탈출 (템플릿화)    
기본적인 K8s 방식으로는 환경(개발, 테스트, 운영)마다 거의 비슷한 YAML 파일을 복사해서 수정해야 한다. Helm 은 템플릿을 사용해 하나의 차트(Chart)로 여러 환경에 대응할 수 있게 해준다. values.yaml 파일 설정만 바꾸면 CPU 할당량이나 이미지 태그 같은 설정값이 자동으로 주입된다. 

* 버전 관리와 손쉬운 롤백      
Helm은 배포할 때마다 릴리스(Release)라는 단위로 이력을 기록한다. 배포 중 문제가 생기면 helm rollback 명령어 한 번으로 이전 상태로 즉시 되돌릴 수 있어 서비스 장애 대응이 매우 빠르다. 

* 복잡한 의존성 해결           
애플리케이션이 DB나 캐시(Redis 등)를 필요로 할 때, 이를 일일이 설치할 필요가 없다. 헬름은 의존성 관리 기능을 통해 필요한 다른 차트들을 자동으로 가져와 함께 설치해 준다.

## Helm 차트 생성 ##

```
cd ~
helm create my-flask
```
helm 에 의해서 만들어진 디렉토리는 다음과 같은 구조를 가지고 있다.
```
my-flask/
├── charts/                # 이 차트가 의존하는 다른 차트들이 저장됨
├── Chart.yaml             # 차트의 이름, 버전, 설명 등 메타데이터
├── values.yaml            # ★ 가장 중요: 모든 설정값(이미지 주소, 리소스 등) 정의
└── templates/             # 실제 쿠버네티스 리소스 템플릿 디렉토리
    ├── NOTES.txt          # 설치 후 사용자에게 보여줄 안내 메시지
    ├── _helpers.tpl       # 이름 공통화 등을 위한 템플릿 함수 정의
    ├── deployment.yaml    # ★ 앱 배포 본체
    ├── config-secret.yaml # ★ 설정 및 비밀값
    ├── service.yaml       # 서비스 노출 설정
    ├── ingress.yaml       # 도메인/외부 접속 설정
    ├── hpa.yaml           # 오토스케일링 설정
    └── tests/             # 설치 후 검증용 테스트 파일
```
* values.yaml: 배포할 때마다 바뀌는 값(ECR 주소, 태그, CPU/메모리)은 여기에 넣는다.
* templates/: 한번 만들어 두면 거의 바꿀 일이 없는 구조 파일들로, 배포 시 이 폴더의 파일들을 읽어 values.yaml의 값과 합쳐서 최종 YAML을 만들어 낸다.


## Flask 어플리케이션 코드 (app.py) ##
이 코드는 SQLAlchemy를 사용하여 PostgreSQL과 연동하며, 유저 생성(Create) 및 조회(Read) API를 포함 한다.
```
import os
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

# 환경 변수로부터 DB 정보 로드
DB_USER = os.getenv('DB_USER', 'admin')
DB_PASS = os.getenv('DB_PASSWORD', 'password123')
DB_HOST = os.getenv('DB_HOST', 'my-flask-db')
DB_NAME = os.getenv('DB_NAME', 'flaskdb')

app.config['SQLALCHEMY_DATABASE_URI'] = f'postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}'
db = SQLAlchemy(app)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)

@app.route('/users', methods=['POST'])
def add_user():
    data = request.json
    new_user = User(username=data['username'])
    db.session.add(new_user)
    db.session.commit()
    return jsonify({"message": "User created"}), 201

@app.route('/users', methods=['GET'])
def get_users():
    users = User.query.all()
    return jsonify([{"id": u.id, "username": u.username} for u in users])

if __name__ == '__main__':
    with app.app_context():
        db.create_all()  # 테이블 자동 생성
    app.run(host='0.0.0.0', port=5000)
```


## Helm values.yaml 설정 ##
AWS 환경에 최적화된 ALB Ingress 설정을 포함한다.
```
# my-flask/values.yaml
replicaCount: 2

image:
  repository: <USER_ID>.dkr.ecr.<REGION>
  tag: "latest"

db:
  image: postgres:13
  user: "admin"
  password: "password123"
  name: "flaskdb"

ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
  hosts:
    - host: ""                  # 실제 도메인이 있다면 입력
      paths:
        - path: /
          pathType: Prefix
```

### 핵심 템플릿 (Deployment & DB) ###
my-flask/templates/deployment.yaml 내에서 컨테이너가 DB 호스트를 인식하도록 연결 한다.
```
# my-flask/templates/deployment.yaml 일부
env:
  - name: DB_HOST
    value: "{{ .Release.Name }}-db"
  - name: DB_USER
    value: {{ .Values.db.user | quote }}
  - name: DB_PASSWORD
    value: {{ .Values.db.password | quote }}
  - name: DB_NAME
    value: {{ .Values.db.name | quote }}
```

my-flask/templates/db.yaml (DB 서비스 정의)
```
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-db
spec:
  ports:
    - port: 5432
  selector:
    app: {{ .Release.Name }}-db
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .Release.Name }}-db
spec:
  serviceName: "{{ .Release.Name }}-db"
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Release.Name }}-db
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-db
    spec:
      containers:
        - name: postgres
          image: {{ .Values.db.image }}
          env:
            - name: POSTGRES_USER
              value: {{ .Values.db.user | quote }}
            - name: POSTGRES_PASSWORD
              value: {{ .Values.db.password | quote }}
            - name: POSTGRES_DB
              value: {{ .Values.db.name | quote }}
```

아래 install 명령어로 배포한다.
```
helm install my-flask ./my-flask
```



## 차트 설치 및 검증 ##
설정한 차트가 정상적으로 렌더링되는지 확인하고 클러스터에 배포한다.
```
helm install --dry-run --debug my-app ./my-app
helm install my-app ./my-app
```




