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
쿠버네티스의 서비스(Service)란 수시로 생성되고 삭제되어 IP 주소가 변하는 파드들에 대해 지속적이고 고정적인 접속 지점을 제공하는 네트워크 객체이다. 파드가 교체될 때마다 접속 정보를 수정해야 하는 번거로움을 해결하기 위해 서비스는 고유한 가상 IP와 이름을 가지며, 라벨(Label)을 기반으로 연결된 파드 집합에 트래픽을 골고루 분산해 주는 로드밸런싱 역할을 수행한다. 결과적으로 서비스는 파드들의 물리적인 위치나 상태 변화와 상관없이 사용자가 일관된 경로로 애플리케이션에 접근할 수 있게 해주는 서비스 디스커버리의 핵심 단위이다.
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
쿠버네티스의 인그레스(Ingress)란 클러스터 외부에서 들어오는 HTTP와 HTTPS 트래픽을 서비스 계층으로 연결해 주는 객체이다. 서비스가 전송 계층(L4)에서 단순한 연결을 담당한다면, 인그레스는 애플리케이션 계층(L7)에서 도메인 이름이나 URL 경로에 따라 트래픽을 서로 다른 서비스로 분산하는 고차원적인 라우팅 규칙을 정의한다. 또한, 보안을 위한 SSL/TLS 인증서 종단 처리와 외부 접속을 위한 단일 진입점 역할을 수행함으로써, 복잡한 서비스 구조를 외부 사용자에게 효율적이고 안전하게 노출하는 클러스터의 최종 경계라고 할 수 있다.
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
쿠버네티스의 컨피그맵(ConfigMap)이란 애플리케이션의 소스 코드와 설정 정보를 분리하여 관리할 수 있게 해주는 데이터 저장 객체이다. 환경 변수, 명령줄 인수, 또는 설정 파일과 같은 데이터를 키-값(Key-Value) 쌍으로 저장하며, 이를 파드에 동적으로 주입함으로써 동일한 컨테이너 이미지를 개발, 테스트, 운영 등 다양한 환경에 맞춰 유연하게 재사용할 수 있게 한다. 결과적으로 컨피그맵은 설정이 변경될 때마다 이미지를 새로 빌드할 필요 없이 외부에서 실행 환경을 제어할 수 있도록 돕는 설정 관리의 핵심 단위이다.
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  WELCOME_MSG: "Hello, Kubernetes!"
```
### Secret ###
쿠버네티스의 시크릿(Secret)이란 비밀번호, OAuth 토큰, ssh 키와 같은 민감한 정보를 안전하게 보관하고 파드에 전달하기 위한 보안 전용 객체이다. 컨피그맵과 유사하게 키-값(Key-Value) 쌍으로 데이터를 관리하지만, 일반 텍스트로 노출되지 않도록 데이터를 Base64로 인코딩하여 저장하며 파드의 메모리에만 임시로 존재하게 함으로써 디스크 노출 위험을 최소화한다. 이를 통해 개발자는 소스 코드나 이미지에 보안 정보를 직접 노출하지 않고도 애플리케이션의 보안 무결성을 유지하며 필요한 인증 정보를 안전하게 주입할 수 있다. 시크릿(Secret)은 민감 정보를 코드와 분리하여 관리하는 편리한 도구이지만, 기본적으로 암호화가 아닌 인코딩 방식을 취하므로 그 자체만으로는 완전한 보안을 보장하지 않는다. 따라서 실무에서는 시크릿의 접근 권한을 엄격히 제한(RBAC)하고, etcd 암호화 설정이나 HashiCorp Vault와 같은 외부 전문 보안 솔루션을 병행하여 데이터의 실제 무결성을 확보해야 한다 
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
쿠버네티스의 서비스 어카운트(Service Account)란 파드 내에서 실행되는 프로세스가 쿠버네티스 API 서버에 접근할 때 사용하는 권한이 부여된 신원(Identity)이다. 쿠버네티스에서 서비스 어카운트는 파드라는 실행 단위에 운영체제의 계정과 같은 자격 증명을 부여하는 최소 단위이며, 해당 파드가 클러스터 내의 다른 자원들을 조회하거나 조작하기 위해 필요한 인증 정보를 담고 있는 스케줄링의 보안 기준이다
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot
```




