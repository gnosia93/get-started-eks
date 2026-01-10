EKS 내부에 GitLab Runner가 설치된 환경에서 Kaniko를 사용하면, 권한 문제(Privileged mode)가 까다로운 Docker-in-Docker(DinD) 없이도 안전하고 빠르게 이미지를 빌드하여 ECR로 푸시할 수 있습니다.
특히 IAM Role for Service Account (IRSA)가 설정되어 있다면 별도의 로그인 과정조차 생략 가능합니다.

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


### 1. Kaniko 기반의 .gitlab-ci.yml ###

```
stages:
  - build
  - package
  - deploy

variables:
  # ECR 레지스트리 주소 (변수로 관리 권장)
  ECR_URL: "123456789.dkr.ecr.ap-northeast-2.amazonaws.com"
  APP_IMAGE: "$ECR_URL/java-gradle-app:$CI_COMMIT_SHORT_SHA"

# 1. Gradle 빌드
build-jar:
  stage: build
  image: gradle:8.4.0-jdk17
  script:
    - ./gradlew clean bootJar
  artifacts:
    paths:
      - build/libs/*.jar

build-jar:
  stage: build
  image: gradle:8.4.0-jdk17
  cache:
    key: ${CI_COMMIT_REF_SLUG} # 브랜치별로 캐시 공유
    paths:
      - .gradle/caches
      - .gradle/wrapper
  variables:
    GRADLE_USER_HOME: $CI_PROJECT_DIR/.gradle
  script:
    - ./gradlew clean bootJar





# 2. Kaniko를 이용한 이미지 빌드 및 ECR 푸시
package-image:
  stage: package
  image:
    name: gcr.io/kaniko-project/executor:debug # debug 태그에 shell이 포함됨
    entrypoint: [""]
  script:
    # ECR 인증을 위한 config 설정 (IRSA가 설정된 경우 자동으로 권한 획득)
    - mkdir -p /kaniko/.docker
    - echo "{\"credsStore\":\"ecr-login\"}" > /kaniko/.docker/config.json
    # Kaniko 빌드 실행
    - /kaniko/executor
      --context "$CI_PROJECT_DIR"
      --dockerfile "$CI_PROJECT_DIR/Dockerfile"
      --destination "$APP_IMAGE"

# 3. GitLab Agent를 이용한 배포
deploy-eks:
  stage: deploy
  image:
    name: bitnami/kubectl:latest
    entrypoint: [""]
  script:
    # GitLab 에이전트 연결 (경로: 프로젝트경로:에이전트명)
    - kubectl config use-context ${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}:my-agent
    - kubectl set image deployment/gradle-app-deploy app-container=$APP_IMAGE
    - kubectl rollout status deployment/gradle-app-deploy
```


### 2. 설정 핵심 포인트 ###
* IRSA (IAM Role for Service Account): Runner가 사용하는 Service Account에 AmazonEC2ContainerRegistryPowerUser 권한이 연결되어 있어야 합니다. 이 경우 Kaniko는 별도의 docker login 없이도 Amazon ECR Docker Credential Helper 기능을 통해 권한을 획득합니다.
* config.json: {"credsStore":"ecr-login"} 설정은 Kaniko가 AWS ECR임을 인지하고 IAM 역할을 사용하도록 유도합니다.
* GitLab Agent 컨텍스트: kubectl config use-context 부분에서 에이전트 이름은 GitLab 에이전트 설정 시 명명한 이름으로 바꿔주세요

### 3. Dockerfile 예시 (프로젝트 루트) ###
Kaniko가 빌드할 때 참조할 Dockerfile입니다. Gradle 빌드 단계에서 생성된 JAR를 복사합니다.
```
FROM openjdk:17-jdk-slim
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
```

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


