## Gitlab 설치하기 ##
com_x86_vscode 서버에 접속해서 gitlab 을 설치한다.
```
ARCH="arm64"
if $(uname -m) == "x86_64" then
   ARCH="amd64"
fi

# 아키텍처 자동 감지 및 변수 할당
ARCH="arm64"
if [ "$(uname -m)" = "x86_64" ]; then
   ARCH="amd64"
fi

echo "Detected Architecture: $ARCH"
sudo dnf install -y https://gitlab.com/gitlab-org/cli/-/releases/v1.80.4/downloads/glab_1.80.4_linux_${ARCH}.rpm

export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export PUBLIC_HOSTNAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
        -s http://169.254.169.254/latest/meta-data/public-hostname)
export EXTERNAL_URL="http://${PUBLIC_HOSTNAME}"

sudo EXTERNAL_URL="${EXTERNAL_URL}" yum install -y gitlab-ce
#curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
sudo dnf install -y gitlab-ce
sudo gitlab-ctl reconfigure
```

* sudo gitlab-ctl reconfigure / restart / status / stop
* sudo yum remove gitlab-ce

### 로그인 하기 ###

![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-login.png)
root 계정의 패스워드를 확인후 웹브라우저를 이용하여 80 포트로 접속한다. 
```
sudo cat /etc/gitlab/initial_root_password
```

### 개인 액세스 토큰(Personal Access Token, PAT) 발급 ###

* GitLab 로그인: 관리자(Admin) 권한이 있는 계정으로 접속한다.
* 프로필 설정 이동: 오른쪽 상단 본인 아바타 아이콘을 클릭하고 [Edit profile]을 선택한다.
* 액세스 토큰 메뉴: 왼쪽 사이드바 메뉴에서 [Personal Access Tokens]를 클릭한다.
* 신규 토큰 추가: [Add new token] 버튼을 클릭한다.
  
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-pat.png)
화면상단의 Personal Access Token 을 복사한다. 

### 인스턴스 러너 생성 ###
Personal Access Token 으로 UI에 접속하지 않고, 터미널에서 인스턴스 러너를 생성할 수 있다.
```
export PAT="glpat-TIlwRz0kvlG8hdcsA3lkk286MQp1OjEH.01.0w1m1mj21"

curl --request POST "${EXTERNAL_URL}/api/v4/user/runners" \
     --header "PRIVATE-TOKEN: ${PAT}" \
     --data "runner_type=instance_type" \
     --data "tag_list=shared"
```
```
{"id":8,"token":"glrt-BpLcXPsNgAebzQEKKJ5nT286MQp0OjEKdToxCw.01.120gf0ysn","token_expires_at":null}
```


### EKS 에 Gitlab 러너 설치 ###
Gitlab 러너는 CI 툴로 소스 코드에 대한 빌드, 테스트, 배포 스크립트 실행을 담당한다. GitLab 서버와 별개의 서버, PC, Docker 컨테이너, 또는 Kubernetes 클러스터 어디든 설치 될수 있다.
```
cat <<EOF > gitlab-values.yaml
gitlabUrl: "${EXTERNAL_URL}"                                                              # 본인의 GitLab 서버 주소
runnerRegistrationToken: "glrt-BpLcXPsNgAebzQEKKJ5nT286MQp0OjEKdToxCw.01.120gf0ysn"       # 확인한 토큰 입력

rbac:
  create: true

serviceAccount:
  create: true                          # 러너를 위한 서비스 계정을 자동으로 생성함
  name: "gitlab-runner"              # 비워두면 차트가 이름을 자동으로 생성 (필요시 지정 가능)

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
helm repo add gitlab https://charts.gitlab.io
helm repo update

kubectl create namespace gitlab-runner
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  -f gitlab-values.yaml

kubectl get pods -n gitlab-runner
```

---

## GitLab 에이전트 설정 ##
* 프로젝트 생성: GitLab에 프로젝트를 만듭니다 (예: my-app).
* 설정 파일 생성: .gitlab/agents/my-k8s-agent/config.yaml 파일을 만들고 내용은 비워두거나 ci_access: projects: - id: path/to/my-app를 적습니다.
* 에이전트 등록: GitLab UI에서 Operate > Kubernetes clusters로 이동해 Connect a cluster를 눌러 에이전트를 등록하고, 제공되는 helm 명령어를 복사합니다.
* 클러스터에 설치: 본인의 쿠버네티스 클러스터(터미널)에서 복사한 helm 명령어를 실행하여 에이전트를 설치합니다.

### 1. 프로젝트 생성 하기 ###

* gitlab UI 에서 my-app 프로젝트를 생성한다


simplespring Git 레포지토리를 클론닝한다.
```
git clone http://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com/root/simplespring.git
cd simplespring
```

Git 푸시를 위한 자격증명을 등록한다. 
```
git config --global credential.helper store
touch ~/.git-credentials
chmod 600 ~/.git-credentials
echo "http://root:${PAT}@ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com" >> ~/.git-credentials
git remote set-url origin ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com
```

```
git push
```
[결과]
```
Enumerating objects: 4, done.
Counting objects: 100% (4/4), done.
Delta compression using up to 16 threads
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 301 bytes | 301.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0 (from 0)
To http://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com/root/simplespring.git
   0934f0e..df62ab4  master -> master
```

### 2. 설정 파일 생성 및 푸시 ###
```
my-app/ (내 프로젝트 루트)
├── .git/
├── .gitlab/                <-- 직접 생성
│   └── agents/
│       └── my-k8s-agent/   <-- 에이전트 이름 (자유롭게 지정)
│           └── config.yaml <-- 설정 파일
├── src/
└── README.md
```

```
mkdir -p .gitlab/agents/my-k8s-agent
touch .gitlab/agents/my-k8s-agent/config.yaml

git add *
git commit -m "configuration for k8s agent"
git push
```
이렇게 파일을 만들고 Gitlab 서버로 푸시하면, 웹 UI의 [Operate > Kubernetes clusters] 메뉴에서 이 에이전트(my-k8s-agent)를 인식하고 등록할 수 있게 된다.



===

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





## 레퍼런스 ##

* https://gitlab.com/gitlab-org/cli/-/releases






