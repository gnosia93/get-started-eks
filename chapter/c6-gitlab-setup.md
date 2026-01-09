## Gitlab 설치하기 ##
com_x86_vscode 서버에 접속해서 gitlab 을 설치한다.
```
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_HOSTNAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
        -s http://169.254.169.254/latest/meta-data/public-hostname)
export EXTERNAL_URL="http://${PUBLIC_HOSTNAME}"
echo ${EXTERNAL_URL}

sudo EXTERNAL_URL="${EXTERNAL_URL}" yum install -y gitlab-ce
#curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
sudo dnf install -y gitlab-ce
sudo gitlab-ctl reconfigure
```

* sudo gitlab-ctl reconfigure
* sudo gitlab-ctl restart
* sudo gitlab-ctl status
* sudo gitlab-ctl stop
* sudo yum remove gitlab-ce

### 로그인 하기 ###

![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-login.png)
root 계정의 패스워드를 확인후 웹브라우저를 이용하여 80 포트로 접속한다. 
```
sudo cat /etc/gitlab/initial_root_password
```

### EKS 용 Gitlab Runner 설치 ###
```
cat <<EOF > gitlab-values.yaml
gitlabUrl: "[http://192.168.x.x](http://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com)"   # 본인의 GitLab 서버 주소
runnerRegistrationToken: "glrt-Q-rSzPYybeTGFUbTftdemm86MQp0OjEKdToxCw.01.1215ac9ya"                 # 확인한 토큰 입력

rbac:
  create: true

runners:
  # 러너가 빌드 시 사용할 기본 이미지
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "gitlab-runner"
        image = "ubuntu:22.04"
        privileged = true                                  # Docker-in-Docker(DinD) 사용 시 필요
EOF
```
```
# 헬름 레포지토리 등록
helm repo add gitlab https://charts.gitlab.io
helm repo update

# 네임스페이스 생성
kubectl create namespace gitlab-runner

# 헬름 차트 설치
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  -f gitlab-values.yaml

# gitlab runner pod 확인
kubectl get pods -n gitlab-runner
```

---

### 2단계: 클러스터 연결을 위한 GitLab Agent 설정 ###
쿠버네티스에 안전하게 배포하기 위해 앞서 문의하신 에이전트를 설정합니다.
* 프로젝트 생성: GitLab에 프로젝트를 만듭니다 (예: my-app).
* 설정 파일 생성: .gitlab/agents/my-k8s-agent/config.yaml 파일을 만들고 내용은 비워두거나 ci_access: projects: - id: path/to/my-app를 적습니다.
* 에이전트 등록: GitLab UI에서 Operate > Kubernetes clusters로 이동해 Connect a cluster를 눌러 에이전트를 등록하고, 제공되는 helm 명령어를 복사합니다.
* 클러스터에 설치: 본인의 쿠버네티스 클러스터(터미널)에서 복사한 helm 명령어를 실행하여 에이전트를 설치합니다.

### 3단계: 도커 이미지 저장소(Registry) 준비 ###
빌드된 이미지를 저장할 공간이 필요합니다.
* 방법: GitLab에는 기본적으로 Container Registry 기능이 내장되어 있습니다.
* .gitlab-ci.yml에서 CI_REGISTRY_IMAGE 변수를 사용하여 자동으로 이미지를 밀어넣을(Push) 수 있습니다.

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







### 1. sign in ###
Initial sign-in
After GitLab is installed, go to the URL you set up and use the following credentials to sign in:

* Username: root
* Password: See /etc/gitlab/initial_root_password














#### 1. GitLab Agent for Kubernetes 활용 (권장) ####
   
이 방식은 클러스터에 에이전트를 설치하여 GitLab과 보안 연결을 유지하며, 별도의 AWS 자격 증명을 노출하지 않고 배포할 수 있는 현대적인 방법입니다. 

준비 단계:
* GitLab 프로젝트 내 .gitlab/agents/`<agent-name>`/config.yaml 파일을 생성하여 에이전트를 정의합니다. 여기서 <agent-name>은 GitLab UI에서 에이전트를 등록할 때 지정한 이름과 반드시 일치해야 합니다.



* GitLab UI의 Infrastructure > Kubernetes clusters 메뉴에서 'Connect a cluster (agent)'를 선택하고 에이전트를 등록합니다.
* 발급된 등록 토큰을 사용해 Helm으로 EKS 클러스터 내에 에이전트를 설치합니다.

배포 방식:
* 파이프라인 .gitlab-ci.yml 파일에서 kubectl 컨텍스트를 해당 에이전트로 설정하면 클러스터에 직접 명령어를 보낼 수 있습니다
