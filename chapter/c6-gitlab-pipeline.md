## GitLab CI/CD 동작 프로세스 (EKS 환경) ##

* 이벤트 감지: 사용자가 소스 코드를 git push하면 GitLab 서버가 이를 감지한다. 서버는 프로젝트 루트의 .gitlab-ci.yml 파일을 확인하여 실행할 파이프라인을 생성한다.
* 작업 수신 (Long Polling): 등록된 GitLab 러너(Runner)는 서버에 주기적으로 요청을 보내는 롱폴링(Long Polling) 방식을 통해 자신에게 할당된 작업이 있는지 체크한다. 러너는 서버 주소와 인증용 토큰을 통해 GitLab과의 연결을 전담한다.
* 익스큐터(Executor) 생성: 할당된 작업을 확인한 러너는 EKS API를 호출하여 독립적인 빌드 전용 파드(Kubernetes Executor)를 동적으로 생성한다.
* 환경 준비 (Helper Container): 메인 빌드 컨테이너가 구동되기 전, Helper 컨테이너가 먼저 실행된다. 이 컨테이너는 GitLab 서버로부터 소스 코드를 clone하고, 필요한 캐시(Cache)와 아티팩트(Artifact)를 복원하여 빌드 환경을 구축한다.
* 파이프라인 실행: 환경 준비가 끝나면 파드 내에서 .gitlab-ci.yml에 명시된 CI/CD 파이프라인이 순차적으로 실행된다. 모든 작업이 완료되면 익스큐터 파드는 자동으로 삭제된다.
* 작업당 하나의 빌드 전용 파드(Kubernetes Executor)가 생성된다. 아래 예제에서 스테이지가 build / package / deploy 로 구성된 경우 이들은 개별 작업들이므로 3개의 파드다 생성되어 순차적으로 실행된다. 

#### 태그(Tag) 설정 ####
만약 러너를 설치할 때 tags를 지정했다면(예: gradle-build) .gitlab-ci.yml의 각 작업에도 똑같이 tags를 입력해야 한다.
태그가 안 맞으면 러너는 자기 일이 아니라고 생각하고 무시한다.
```
build-jar:
  tags:
    - my-eks-runner # 러너 등록 시 설정한 태그명
```

## Kaniko 기반의 CI/CD 구성 ##
#### .gitlab-ci.yml 위치 ####
```
my-java-project/
├── .gradle/
├── .gitlab-ci.yml  <-- 바로 여기에 위치!
├── build.gradle
├── src/
├── Dockerfile
└── gradlew
```
파일을 만들고 git push를 한 뒤, GitLab 웹 화면의 왼쪽 사이드바에서 Build > Pipelines 메뉴를 클릭해 보세요. 파이프라인이 생성되어 돌아가고 있다면 위치가 정확한 것입니다.

EKS 내부에 GitLab Runner가 설치된 환경에서 Kaniko를 사용하면, Privileged 모드 설정이 필요한 Docker-in-Docker(DinD) 없이도 안전하고 빠르게 이미지를 빌드하여 ECR로 푸시할 수 있다. 특히 IAM Role for Service Account (IRSA)가 설정되어 있다면 별도의 로그인 과정조차 생략 할 수 있다.
아래와 같은 설정으로 .gitlab-ci.yml 파일을 수정한다. 

#### Dockerfile  ####
Kaniko가 빌드할 때 참조할 Dockerfile 로 Gradle 빌드 단계에서 생성된 JAR를 복사한다.
```
FROM openjdk:17-jre-headless

WORKDIR /app

# GitLab 아티팩트 경로에서 JAR 복사
COPY build/libs/*.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]
```

#### .gitlab-ci.yml ####
```
default:
  tags:
    - my-eks-runner

stages:
  - build
  - package
  - deploy

variables:
  ECR_URL: "${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com"
  APP_IMAGE: "${ECR_URL}/${REPO_NAME}:${CI_COMMIT_SHORT_SHA}"

# 1. Gradle 빌드 및 아티팩트 저장
build-jar:
  stage: build
  image: gradle:9.2.1-jdk17-ubi
  script:
    - ./gradlew clean bootJar
  artifacts:
    paths:
      - build/libs/*.jar     # 이 경로의 파일을 GitLab 서버로 전송
    expire_in: 1 hour        # 서버 공간 확보를 위해 1시간 후 자동 삭제

# 2. Kaniko 이미지 빌드 (자동으로 아티팩트 수신)
package-image:
  stage: package
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    # GitLab Runner가 build/libs/*.jar 파일을 이미 이 컨테이너 안에 복원해 둠
    # config.json: {"credsStore":"ecr-login"} 설정은 Kaniko가 AWS ECR임을 인지하고 IAM 역할을 사용하도록 유도
    - mkdir -p /kaniko/.docker
    - echo "{\"credsStore\":\"ecr-login\"}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
      --destination "${APP_IMAGE}"

# 3. GitLab Agent를 이용한 배포
deploy-eks:
  stage: deploy
  image:
    name: bitnami/kubectl:latest
    entrypoint: [""]
  script:
    # GitLab 에이전트 연결 (경로: 프로젝트경로:에이전트명)
    # my-agent 는 앞에서 설정한 Gitlab 에이전트의 명칭이다.
    - kubectl config use-context ${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}:my-agent
    - kubectl set image deployment/gradle-app-deploy app-container=$APP_IMAGE
    - kubectl rollout status deployment/gradle-app-deploy
```
* IRSA (IAM Role for Service Account): Runner가 사용하는 Service Account에 AmazonEC2ContainerRegistryPowerUser 권한이 연결되어 있어야 한다. 이 경우 Kaniko는 별도의 docker login 없이도 Amazon ECR Docker Credential Helper 기능을 통해 권한을 획득한다.

## 오토스케일링 (Dynamic Provisioning) ##
GitLab Runner를 Kubernetes Executor 모드로 설정하면, 빌드 요청마다 새로운 파드가 생성되고 작업 종료 후 자동 삭제됩니다.
Helm Chart로 설치했다면 values.yaml을 다음과 같이 수정하세요:
```
# 동시 실행 가능한 최대 파드 수
## 1. 전체 러너가 동시에 실행할 작업 수 (기본값이 매우 작을 수 있음)
concurrent: 10

runners:
  ## 2. 특정 러너에 할당된 동시 작업 수
  limit: 10
  config: |
    [[runners]]
      [runners.kubernetes]
        ## 3. 빌드 파드가 생성될 네임스페이스
        namespace = "gitlab-runner"
        ## 4. 빌드 파드 자원 할당 (성능 직결)
        cpu_request = "1"
        memory_request = "2Gi"
        service_account = "gitlab-runner-sa" # IRSA 설정된 계정

#2. Gradle 빌드 속도 뻥튀기 (S3 캐시)
#매번 라이브러리를 새로 받으면 파드가 아무리 많이 떠도 느립니다. EKS 환경이니 AWS S3를 캐시 저장소로 쓰면 모든 동적 파드가 라이브러리를 공유합니다.
runners:
  cache:
    secretName: s3access  # S3 Access Key가 담긴 Kubernetes Secret
    cacheType: s3
    s3ServerAddress: s3.amazonaws.com
    cacheBucketName: my-gitlab-runner-cache
    cacheBucketLocation: ap-northeast-2
```

## Kaniko 빌드 속도 올리기 (캐싱) ##
Kaniko는 매번 레이어를 새로 빌드하면 느립니다. ECR을 캐시 저장소로 활용하도록 스크립트를 보강하세요.
```
# .gitlab-ci.yml의 package 단계 수정
package-image:
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"credsStore\":\"ecr-login\"}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context "$CI_PROJECT_DIR"
      --dockerfile "$CI_PROJECT_DIR/Dockerfile"
      --destination "$APP_IMAGE"
      --cache=true # 캐시 활성화
      --cache-repo "$ECR_URL/kaniko-cache" # ECR에 캐시 레이어 저장
```

## 추가 팁: Gradle 캐시 공유 ##
Gradle은 의존성(Dependencies) 다운로드 시간이 깁니다. EKS 내부에 S3 분산 캐시를 설정하거나, PVC(Persistent Volume Claim)를 러너 파드에 마운트하여 .gradle/caches를 공유하면 빌드 속도가 비약적으로 빨라집니다.
현재 러너가 직접 설치한 바이너리 형태인가요, 아니면 Helm으로 설치한 Kubernetes Executor인가요? 설치 방식에 따라 config.toml 수정법이 다릅니다.


```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GitLabRunnerCacheAccess",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
        },
        {
            "Sid": "GitLabRunnerBucketList",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME"
        }
    ]
}
```

2. 설정 시 주의사항
보안 최적화: Resource를 특정 버킷으로 제한하여 Runner가 다른 S3 데이터를 건드리지 못하게 합니다.
버킷 생명주기(Lifecycle): 캐시는 시간이 지나면 쌓여서 비용이 발생합니다. Amazon S3 Lifecycle 설정을 통해 7일~14일이 지난 객체는 자동으로 삭제되도록 설정하는 것이 좋습니다.
IRSA 연결: EKS에서는 eksctl 등을 사용해 위 정책이 담긴 IAM Role을 Runner의 ServiceAccount에 매핑하세요.


----

## S3 캐시 설정 ##
#### 1. S3 버킷 및 IAM 권한 준비 ####
* 먼저 캐시를 담을 S3 버킷을 생성하고, GitLab Runner IAM 정책을 연결합니다.
* S3 버킷 생성: my-gitlab-runner-cache (이름 자유)
* IAM 정책 연결: 앞서 안내해 드린 S3 권한 JSON을 Runner가 사용하는 IAM Role(IRSA)에 할당하세요.

#### 2. Helm values.yaml 수정 ####
이제 GitLab Runner가 S3를 인지하도록 Helm 설정을 변경합니다. (Access Key 방식보다 IRSA 방식을 권장하지만, 설정을 명확히 하기 위해 통합 구조로 보여드립니다.)
```
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        # IRSA 사용 시 아래 주석 해제 (권장)
        # service_account = "gitlab-runner-sa" 
      [runners.cache]
        Type = "s3"
        Path = "runner-cache"      # 버킷 내 저장 경로
        Shared = true             # 모든 러너 파드가 캐시 공유 (중요!)
        [runners.cache.s3]
          ServerAddress = "s3.amazonaws.com"
          BucketName = "my-gitlab-runner-cache"
          BucketLocation = "ap-northeast-2"
          # IRSA를 안 쓴다면 아래 Secret 설정 필요
          # AuthenticationType = "access-key" 
```
### 3. .gitlab-ci.yml에서 캐시/아티팩트 최적화 ###
```
variables:
  GRADLE_USER_HOME: $CI_PROJECT_DIR/.gradle

build-jar:
  stage: build
  image: gradle:8.4.0-jdk17
  cache:
    key: "gradle-cache-$CI_COMMIT_REF_SLUG" # 브랜치별 캐시 분리
    paths:
      - .gradle/caches
      - .gradle/wrapper
  script:
    - ./gradlew clean bootJar
  artifacts:
    # JAR 파일은 다음 단계(Kaniko) 전달용으로 최소한만 유지
    paths:
      - build/libs/*.jar
    expire_in: 1 hrs # 금방 지워지게 설정해서 S3 용량 절약
```

```
이 캐시가 제대로 작동하려면 Gradle이 프로젝트 폴더 안의 캐시를 사용하도록 강제해야 합니다. .gitlab-ci.yml 상단 variables에 이걸 꼭 넣어주세요:
yaml
variables:
  # Gradle이 캐시를 프로젝트 루트(.gradle)에 저장하도록 설정 (그래야 GitLab이 인식함)
  GRADLE_USER_HOME: $CI_PROJECT_DIR/.gradle
```

## 스테이지 ##
추천하는 추가 스테이지
* Test: 빌드 전 단위 테스트(JUnit) 수행 (실패 시 배포 중단)
```
unit-test:
  stage: test
  image: gradle:8.4.0-jdk17
  script:
    - ./gradlew test
  artifacts:
    when: always
    reports:
      junit: build/test-results/test/**/TEST-*.xml
```
* Lint / Static Analysis: 코드 스타일 및 잠재적 버그 체크 (SonarQube 등)
* Security Scan: 라이브러리 취약점 점검 (Trivy, Snyk)
```
container-scan:
  stage: scan
  image: 
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    - trivy image --exit-code 0 --severity HIGH,CRITICAL $APP_IMAGE
```
* Cleanup: 임시 리소스 정리

```
stages:
  - test        # 1. 코드 검증
  - build       # 2. JAR 생성
  - scan        # 3. 보안 점검 (이미지 취약점)
  - package     # 4. 이미지 빌드
  - deploy      # 5. EKS 배포
```

[Manual Deploy (승인 후 배포)]
실수로 main 브랜치에 푸시하자마자 운영 서버에 바로 배포되는 걸 막으려면 when: manual을 씁니다.

```
deploy-eks:
  stage: deploy
  when: manual  # 깃랩 UI에서 버튼을 눌러야만 배포 시작
  script:
    - ... (기존 배포 스크립트)

```
---
## Helm ##
이미 EKS에 GitLab Runner를 설치할 때 Helm을 사용하셨기 때문에, 배포(Deploy) 단계에서도 Helm을 쓰면 관리가 훨씬 편해집니다. kubectl set image는 임시방편일 뿐, 실무에서는 Helm을 이용해 버전 관리를 하는 게 정석입니다.

###1. 배포 스크립트 수정 (.gitlab-ci.yml) ###
kubectl 대신 helm 명령어를 사용하도록 변경합니다.
```
deploy-eks:
  stage: deploy
  image:
    name: alpine/helm:latest # helm이 설치된 가벼운 이미지
    entrypoint: [""]
  script:
    # 1. GitLab 에이전트 연결
    - kubectl config use-context ${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}:my-agent
    # 2. Helm 업그레이드 (차트가 프로젝트 내 'charts/my-app'에 있다고 가정)
    - helm upgrade --install my-java-app ./charts/my-app \
        --namespace my-namespace \
        --set image.repository=$ECR_REGISTRY/java-gradle-app \
        --set image.tag=$CI_COMMIT_SHORT_SHA \
        --wait
```

### 2. Helm 차트 위치 ###
프로젝트 폴더 안에 배포용 설정(Chart)을 미리 넣어두어야 합니다.
```
my-java-project/
├── charts/
│   └── my-app/         # helm create로 만든 기본 구조
│       ├── Chart.yaml
│       └── values.yaml  # 여기에 image tag 등을 변수로 비워둠
├── .gitlab-ci.yml
└── ...

```
### 3. 왜 Helm을 끼워 넣나요? ###
* 롤백(Rollback): 배포가 잘못되면 helm rollback 한 줄로 이전 상태 복구가 가능합니다. Helm 공식 문서를 참고하세요.
* 환경별 관리: values-dev.yaml, values-prod.yaml처럼 파일만 바꿔서 개발/운영 서버 설정을 다르게 할 수 있습니다. GitLab CI/CD 환경 변수와 조합하면 매우 강력합니다.
* 한꺼번에 변경: Deployment, Service, Ingress 등 여러 리소스를 명령어 하나로 동시에 배포합니다.


----
## 멀티 아키텍처 이미지 빌드 ##

variables:
  APP_IMAGE: "$ECR_REGISTRY/java-gradle-app"

# 1 & 2단계: 각각 빌드 (병렬 실행)
```
build-multi-arch:
  stage: package
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  parallel:
    matrix:
      - ARCH: [amd64, arm64] # 두 가지를 동시에 돌림
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"credsStore\":\"ecr-login\"}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context "$CI_PROJECT_DIR"
      --dockerfile "$CI_PROJECT_DIR/Dockerfile"
      # 이미지를 아키텍처별 태그로 각각 푸시 (예: :sha-amd64, :sha-arm64)
      --destination "$APP_IMAGE:$CI_COMMIT_SHORT_SHA-$ARCH"
      --customPlatform "linux/$ARCH"
```
# 3단계: 두 이미지를 하나로 합치기 (Manifest Push)
```
create-manifest:
  stage: package
  needs: ["build-multi-arch"]
  image: curlimages/curl:latest
  before_script:
    - apk add --no-cache docker-cli # docker manifest 명령어를 쓰기 위함
  script:
    - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    # 개별 이미지들을 하나의 태그($CI_COMMIT_SHORT_SHA)로 묶음
    - docker manifest create $APP_IMAGE:$CI_COMMIT_SHORT_SHA \
        $APP_IMAGE:$CI_COMMIT_SHORT_SHA-amd64 \
        $APP_IMAGE:$CI_COMMIT_SHORT_SHA-arm64
    - docker manifest push $APP_IMAGE:$CI_COMMIT_SHORT_SHA
```
1. 스테이지 분리 구성 (추천)
```
stages:
  - build    # Gradle 빌드
  - package  # 아키텍처별 이미지 빌드 (Kaniko)
  - manifest # 이미지 합치기 (Docker Manifest)
  - deploy   # EKS 배포

# 개별 빌드 Job
build-multi-arch:
  stage: package
  parallel:
    matrix:
      - ARCH: [amd64, arm64]
  # ... (Kaniko 설정)

# 합치기 Job
create-manifest:
  stage: manifest # <-- 스테이지를 따로 두면 가독성이 좋아짐
  needs: ["build-multi-arch"] # 앞선 빌드가 모두 끝나야 실행됨
  # ... (Docker Manifest 설정)

```
