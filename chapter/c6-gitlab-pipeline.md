
## 3단계 도커 이미지 저장소(Registry) 준비 ##
빌드된 이미지를 저장할 공간이 필요합니다.
* 방법: GitLab에는 기본적으로 Container Registry 기능이 내장되어 있습니다.
* .gitlab-ci.yml에서 CI_REGISTRY_IMAGE 변수를 사용하여 자동으로 이미지를 밀어넣을(Push) 수 있습니다.



-----
### 4단계: CI/CD 파이프라인 작성 (.gitlab-ci.yml) ###
프로젝트 루트 폴더에 이 파일을 만듭니다. 이것이 "푸시하면 자동 실행"되는 핵심 스크립트입니다.
```
stages:
  - build
  - deploy

# 1. 빌드 단계: 도커 이미지 생성 및 푸시
build_image:
  stage: build
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# 2. 배포 단계: 에이전트를 통해 쿠버네티스에 명령 전달
deploy_app:
  stage: deploy
  image:
    name: bitnami/kubectl:latest
    entrypoint: [""]
  script:
    # 에이전트 연결 설정
    - kubectl config use-context path/to/my-app:my-k8s-agent
    # 이미지 업데이트 및 배포
    - kubectl set image deployment/my-deployment-name my-container=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

### 5단계: 코드 푸시 및 확인 ###
* 작성한 코드, Dockerfile, 쿠버네티스 manifest.yaml (Deployment/Service), 그리고 .gitlab-ci.yml을 Git에 커밋하고 푸시합니다.
* GitLab 프로젝트의 Build > Pipelines 메뉴에서 자동으로 빌드와 배포가 진행되는지 확인합니다.
---
