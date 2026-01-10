쿠버네티스(K8s) 애플리케이션을 헬름(Helm)으로 관리(패키징)해야 하는 이유는 단순히 '편해서'를 넘어 운영의 복잡성을 해결하기 위해서입니다. 주요 이유는 다음과 같습니다.
* 매니페스트 지옥 탈출 (템플릿화)
기본적인 K8s 방식으로는 환경(개발, 테스트, 운영)마다 거의 비슷한 YAML 파일을 복사해서 수정해야 합니다. 헬름은 Go 템플릿을 사용해 하나의 차트(Chart)로 여러 환경에 대응할 수 있게 해줍니다. values.yaml 파일 하나만 바꾸면 CPU 할당량이나 이미지 태그 같은 설정값이 자동으로 주입됩니다. 
* 버전 관리와 손쉬운 롤백
헬름은 배포할 때마다 릴리스(Release)라는 단위로 이력을 기록합니다. 배포 중 문제가 생기면 helm rollback 명령어 한 번으로 이전 상태로 즉시 되돌릴 수 있어 서비스 장애 대응이 매우 빠릅니다. 
* 복잡한 의존성 해결
애플리케이션이 DB나 캐시(Redis 등)를 필요로 할 때, 이를 일일이 설치할 필요가 없습니다. 헬름은 의존성 관리 기능을 통해 필요한 다른 차트들을 자동으로 가져와 함께 설치해 줍니다


## 스프링부트 어플리케이션 차트 만들기 ##

helm 차트를 만든다.
```
helm create my-spring-chart
```

다음과 같은 디렉토리 구조의 차트가 만들어 진다.
```
my-spring-app/
├── charts/                # 이 차트가 의존하는 다른 차트들이 저장됨 (비어있음)
├── Chart.yaml             # 차트의 이름, 버전, 설명 등 메타데이터
├── values.yaml            # ★ 가장 중요: 모든 설정값(이미지 주소, 리소스 등) 정의
└── templates/             # 실제 쿠버네티스 리소스 템플릿 디렉토리
    ├── NOTES.txt          # 설치 후 사용자에게 보여줄 안내 메시지
    ├── _helpers.tpl       # 이름 공통화 등을 위한 템플릿 함수 정의
    ├── deployment.yaml    # ★ 앱 배포 본체 (아까 만든 코드)
    ├── config-secret.yaml # ★ 설정 및 비밀값 (새로 만든 파일)
    ├── service.yaml       # 서비스 노출 설정
    ├── ingress.yaml       # 도메인/외부 접속 설정
    ├── hpa.yaml           # 오토스케일링 설정
    └── tests/             # 설치 후 검증용 테스트 파일
```
* values.yaml: 배포할 때마다 바뀌는 값(ECR 주소, 태그, CPU/메모리)은 여기에 넣는다.
* templates/: 한 번 짜두면 거의 바꿀 일이 없는 구조 파일들로, 배포 시 이 폴더의 파일들을 읽어 values.yaml의 값과 합쳐서 최종 YAML을 만들어 낸다.

### 1. values.yaml ###
모든 변수를 여기서 관리한다. 나중에 운영용(prod), 개발용(dev) 파일을 따로 만들수도 있다.
```
replicaCount: 4

image:
  repository: "1234567890.dkr.ecr.ap-northeast-2.amazonaws.com"
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  host: my-spring-app.com

resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "500m"
    memory: "1Gi"

# 환경변수(ConfigMap/Secret)를 위한 공간
env:
  config:
    SPRING_PROFILES_ACTIVE: "prod"
    DB_URL: "jdbc:mysql://db-host:3306/mydb"
  secret:
    DB_PASSWORD: "super-secret-password"
```

### 2. templates/config-secret.yaml ###
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "my-spring-app.fullname" . }}-config
data:
{{- toYaml .Values.env.config | nindent 2 }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "my-spring-app.fullname" . }}-secret
type: Opaque
stringData:
{{- toYaml .Values.env.secret | nindent 2 }}
```

### 3. templates/deployment.yaml (앱 본체) ###
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-spring-app.fullname" . }}
  labels:
    {{- include "my-spring-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-spring-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-spring-app.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: spring-boot-container
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 8080
        # ConfigMap과 Secret에 있는 모든 값을 환경변수로 가져옵니다.
        envFrom:
        - configMapRef:
            name: {{ include "my-spring-app.fullname" . }}-config
        - secretRef:
            name: {{ include "my-spring-app.fullname" . }}-secret
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

### 4. 배포하기 ###
```
# 문법 체크
helm lint ./my-spring-app

# 배포 실행
helm install my-app ./my-spring-app
```
