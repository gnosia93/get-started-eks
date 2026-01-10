EKS 내부에 GitLab Runner가 설치된 환경에서 Kaniko를 사용하면, 권한 문제(Privileged mode)가 까다로운 Docker-in-Docker(DinD) 없이도 안전하고 빠르게 이미지를 빌드하여 ECR로 푸시할 수 있습니다.
특히 IAM Role for Service Account (IRSA)가 설정되어 있다면 별도의 로그인 과정조차 생략 가능합니다.

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


