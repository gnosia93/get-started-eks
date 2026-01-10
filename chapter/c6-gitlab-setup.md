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

![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-login-root.png)
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


## GitLab 에이전트 설정 ##
* 프로젝트 생성: GitLab에 프로젝트를 만듭니다 (예: my-app).
* 설정 파일 생성: .gitlab/agents/my-k8s-agent/config.yaml 파일을 만들고 내용은 비워두거나 ci_access: projects: - id: path/to/my-app를 적습니다.
* 에이전트 등록: GitLab UI에서 Operate > Kubernetes clusters로 이동해 Connect a cluster를 눌러 에이전트를 등록하고, 제공되는 helm 명령어를 복사합니다.
* 클러스터에 설치: 본인의 쿠버네티스 클러스터(터미널)에서 복사한 helm 명령어를 실행하여 에이전트를 설치합니다.

### 1. 프로젝트 생성 하기 ###

좌측 메뉴에서 Projects 으로 이동한 후 우측 상단의 [New project] 버튼을 클릭한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-project-1.png)
Create blank project 를 선택한다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-project-2.png)
아래 그림과 같이 프로젝트 속성값 들을 채우고, [Create porject] 버튼을 클릭한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-project-3.png)
my-app 프로젝트가 생성되었다. 우측 상단의 [Code] 버튼을 클릭하여 Cone with HTTP URL 을 복사한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-project-4.png)


my-app Git 레포지토리를 클론 한다.
```
git clone http://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com/root/my-app.git
cd my-app
```

Git 푸시를 위한 자격증명을 등록한다. 
```
git config --global credential.helper store
touch ~/.git-credentials
chmod 600 ~/.git-credentials
echo "http://root:${PAT}@ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com" >> ~/.git-credentials

git remote set-url origin http://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com/root/my-app.git
```
test.file 을 하나 만들어서 푸시해 본다.
```
touch test.file
echo "test" >> test.file
git add *
git commit -m "test.file added..."
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

### 2. 에어전트 파일 생성 및 푸시 ###
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

git add .
git commit -m "added k8s agent"
git push
```
[결과]
```
[main 5673077] added k8s agent
 Committer: EC2 Default User <ec2-user@ip-10-0-0-183.ap-northeast-1.compute.internal>
Your name and email address were configured automatically based
on your username and hostname. Please check that they are accurate.
You can suppress this message by setting them explicitly:

    git config --global user.name "Your Name"
    git config --global user.email you@example.com

After doing this, you may fix the identity used for this commit with:

    git commit --amend --reset-author

 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 .gitlab/agents/my-k8s-agent/config.yaml
Enumerating objects: 7, done.
Counting objects: 100% (7/7), done.
Delta compression using up to 16 threads
Compressing objects: 100% (2/2), done.
Writing objects: 100% (6/6), 485 bytes | 485.00 KiB/s, done.
Total 6 (delta 0), reused 0 (delta 0), pack-reused 0 (from 0)
To http://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com/root/my-app.git
   e93d69d..5673077  main -> main
```

파일을 만들고 Gitlab 서버로 푸시 한다.

### 3. 에이전트 설치 ###

GitLab UI에서 Operate > Kubernetes clusters로 이동해 Connect a cluster를 눌러 에이전트를 등록하고, 제공되는 helm 명령어를 복사한다.
배포 대상이 되는 쿠버네티스 클러스터(터미널)에서 helm 명령어를 실행하여 에이전트를 설치한다.


## 도커 이미지 저장소(Registry) 준비 ##
빌드된 이미지를 저장할 공간이 필요합니다.
* 방법: GitLab에는 기본적으로 Container Registry 기능이 내장되어 있습니다.
* .gitlab-ci.yml에서 CI_REGISTRY_IMAGE 변수를 사용하여 자동으로 이미지를 밀어넣을(Push) 수 있습니다.



## 레퍼런스 ##

* https://gitlab.com/gitlab-org/cli/-/releases






