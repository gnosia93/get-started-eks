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

GitLab 에이전트는 쿠버네티스 환경에 최적화된 클라우드 네이티브 기반의 지속적 배포(CD) 관리 도구로, 클러스터 내부에서 GitLab 서버와 암호화된 통신 세션을 유지하며 코드 저장소의 매니페스트와 실제 운영 중인 클러스터의 상태를 실시간으로 일치시키는 핵심 엔진 역할을 수행한다. 단순히 배포 명령만 전달하는 과거의 방식에서 벗어나, 방화벽을 허물지 않고도 사설망 내부로 안전한 통로를 구축하는 CI/CD 터널링을 지원하여 파이프라인의 보안성을 극대화하며, 배포 이후에도 클러스터 내 리소스의 변동 사항이나 보안 취약점 정보를 수집하여 개발자에게 실시간으로 피드백하는 통합 운영 프록시로서의 기능을 모두 포함하고 있다. 결과적으로 이 에이전트는 인프라 관리를 코드로 자동화하는 GitOps를 실현하여 수동 배포의 위험을 제거하고, 개발자가 복잡한 인프라 설정 없이도 GitLab 대시보드에서 애플리케이션의 생명주기를 안정적으로 관리할 수 있도록 돕는 고도화된 CD 솔루션이다.

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

GitLab UI에서 Operate > Kubernetes clusters로 이동해 Connect a cluster를 눌러 에이전트를 등록하고, 제공되는 helm 명령어를 복사한다. 배포 대상이 되는 쿠버네티스 클러스터(터미널)에서 helm 명령어를 실행하여 에이전트를 설치한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-1.png)
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-2.png)
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-3.png)
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-4.png)

아래 Helm 차트를 이용하여 get-started-eks 클러스터에 gitlab 에이전트(my-k8s-agent)를 설치한다.  
```
helm repo add gitlab https://charts.gitlab.io
helm repo update
helm upgrade --install my-k8s-agent gitlab/gitlab-agent \
    --namespace gitlab-agent-my-k8s-agent \
    --create-namespace \
    --set image.tag=v18.7.0 \
    --set config.token=glagent-Mvui137jZ0jc_WIzMXx5BG86MQpwOjMH.01.0w06j4m28 \
    --set config.kasAddress=ws://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com:8150/-/kubernetes-agent/
```

설치된 helm 차트를 확인한다. 
```
helm list -A
```
[결과]
```
NAME            NAMESPACE                       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
gitlab-runner   gitlab-runner                   1               2026-01-09 14:41:34.483970234 +0000 UTC deployed        gitlab-runner-0.84.1    18.7.1     
karpenter       karpenter                       1               2026-01-09 14:16:06.750267234 +0000 UTC deployed        karpenter-1.8.1         1.8.1      
my-k8s-agent    gitlab-agent-my-k8s-agent       1               2026-01-10 05:12:10.330080135 +0000 UTC deployed        gitlab-agent-2.22.1     v18.7.1    
```

#### KAS 설정 ####
GitLab 에이전트는 KAS(GitLab Agent Server)와 통신하며 ws:// 프로토콜과 주소 형식에 따라 사용 포트를 결정한다.(현재 설정으로는 80 포트를 통해 통신 시도)
KAS 는 기본적으로 로컬 통신(127.0.0.1) 에 대해서만 열려져 있기 때문에 아래 명령으로 KAS 설정을 수정한다.  
```
sudo tee -a /etc/gitlab/gitlab.rb <<EOF
# GitLab KAS Configuration
gitlab_kas['enable'] = true
gitlab_kas['listen_address'] = '0.0.0.0:8150'      # 외부 접속을 위해 0.0.0.0 설정 (포트 명시)
gitlab_rails['gitlab_kas_external_url'] = 'ws://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com:8150/-/kubernetes-agent/'   # 포트 명시, / 필수.
EOF

sudo gitlab-ctl reconfigure
```
수정후 아래 명령어로 수정 사항을 반영하고 오픈 포트를 다시 확인한다. EC2 시스큐리티 그룹은 8150 포트에 대해서 VPC 또는 EKS 클러스터 레벨에서 오픈되어 있어야 한다. 
```
sudo netstat -tulpn | grep gitlab-kas
```
gitlab 에이전트 로그를 확인하여 Gitlab KAS 통신이 제대로 이뤄지는지 확인한다. 
```
kubectl logs -n gitlab-agent-my-k8s-agent -l app.kubernetes.io/name=gitlab-agent 
```
[결과]
```
{"time":"2026-01-10T05:59:09.017226215Z","level":"INFO","msg":"successfully acquired lease gitlab-agent-my-k8s-agent/agent-2-lock","agent_key":"agentk:2"}
{"time":"2026-01-10T05:59:09.01737551Z","level":"INFO","msg":"Starting","mod_name":"starboard_vulnerability","agent_key":"agentk:2"}
{"time":"2026-01-10T05:59:09.017387895Z","level":"INFO","msg":"Starting","mod_name":"remote_development","agent_key":"agentk:2"}
{"time":"2026-01-10T05:59:09.01739484Z","level":"INFO","msg":"Event occurred","agent_key":"agentk:2","object":{"name":"agent-2-lock","namespace":"gitlab-agent-my-k8s-agent"},"fieldPath":"","kind":"Lease","apiVersion":"coordination.k8s.io/v1","type":"Normal","reason":"LeaderElection","message":"my-k8s-agent-gitlab-agent-v2-85449fbd5f-7h6x6 became leader"}
{"time":"2026-01-10T05:59:08.62389814Z","level":"INFO","msg":"Flux could not be detected or the Agent is missing RBAC, skipping module. A restart is required for this to be checked again","mod_name":"flux"}
{"time":"2026-01-10T05:59:08.623993724Z","level":"INFO","msg":"Starting","mod_name":"agent_registrar"}
{"time":"2026-01-10T05:59:08.624021964Z","level":"INFO","msg":"Starting","mod_name":"google_profiler"}
{"time":"2026-01-10T05:59:08.624026076Z","level":"INFO","msg":"Starting","mod_name":"observability"}
{"time":"2026-01-10T05:59:08.624002986Z","level":"INFO","msg":"Starting","mod_name":"agent2kas_tunnel"}
{"time":"2026-01-10T05:59:08.624416637Z","level":"INFO","msg":"Observability endpoint is up","mod_name":"observability","net_network":"tcp","net_address":"[::]:8080"}
{"time":"2026-01-10T05:59:09.000882585Z","level":"INFO","msg":"attempting to acquire leader lease gitlab-agent-my-k8s-agent/agent-2-lock...","agent_key":"agentk:2"}
{"time":"2026-01-10T05:59:09.023906389Z","level":"ERROR","msg":"error initially creating leader election record: leases.coordination.k8s.io \"agent-2-lock\" already exists","agent_key":"agentk:2"}
```
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-5.png)


## 레퍼런스 ##

* https://gitlab.com/gitlab-org/cli/-/releases






