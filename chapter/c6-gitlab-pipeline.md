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
* EKS 내부에 GitLab Runner가 설치된 환경에서 Kaniko를 사용하면, Privileged 모드 설정이 필요한 Docker-in-Docker(DinD) 없이도 안전하고 빠르게 이미지를 빌드하여 ECR로 푸시할 수 있다. 특히 IAM Role for Service Account (IRSA)가 설정되어 있다면 별도의 로그인 과정조차 생략 할 수 있다.
아래와 같은 설정으로 .gitlab-ci.yml 파일을 수정한다. 
* IRSA (IAM Role for Service Account): Runner가 사용하는 Service Account에 AmazonEC2ContainerRegistryPowerUser 권한이 연결되어 있어야 한다. 이 경우 Kaniko는 별도의 docker login 없이도 Amazon ECR Docker Credential Helper 기능을 통해 권한을 획득한다.

#### .gradle/ 캐시 설정 ####

