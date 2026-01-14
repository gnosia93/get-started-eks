## GitLab 러너(Runner) ##
GitLab 러너는 GitLab CI/CD 파이프라인의 작업(Job)을 할당받아 빌드, 테스트, 배포 등을 실제로 수행하고 결과를 서버에 전송하는 핵심 실행 에이전트이다.
사용 범위에 따라서는 인스턴스 내 모든 프로젝트가 공용으로 사용하는 인스턴스 러너(Shared Runner)와 특정 그룹 내 프로젝트들이 공유하는 그룹 러너(Group Runner), 그리고 단일 프로젝트에 전용으로 할당되는 프로젝트 러너(Specific Runner)로 나뉘어 진다. 
또한 작업을 처리하는 환경인 Executor 방식에 따라서는 설치된 서버의 환경을 그대로 사용하는 Shell, 독립적인 컨테이너 환경을 제공하는 Docker, 그리고 클러스터 자원을 유연하게 관리하는 Kubernetes 등이 대표적이다.

```
export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export PUBLIC_HOSTNAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
        -s http://169.254.169.254/latest/meta-data/public-hostname)
export EXTERNAL_URL="http://${PUBLIC_HOSTNAME}"
```

### 인스턴스 러너 생성 ###
Personal Access Token 으로 UI에 접속하지 않고, 터미널에서 인스턴스 러너를 생성할 수 있다.
```
export PAT="glpat-3VGrYiEAZhOLqil2PFDPfm86MQp1OjEH.01.0w178ykto"

RUNNER_TOKEN=$(curl --request POST "${EXTERNAL_URL}/api/v4/user/runners" \
     --header "PRIVATE-TOKEN: ${PAT}" \
     --data "runner_type=instance_type" \
     --data "tag_list=shared,test" | jq -r .token)
echo ${RUNNER_TOKEN}           
```
여기서는 태그를 shared,test 로 설정하였다. 이 태그 값은 다음장의 CI/CD 파이프라인 생성시 사용된다.

### EKS 에 GitLab 러너 배포 ###
* https://docs.gitlab.com/runner/configuration/advanced-configuration/
```
cat <<EOF > gitlab-values.yaml
gitlabUrl: "${EXTERNAL_URL}"                               # 본인의 GitLab 서버 주소
runnerToken: "${RUNNER_TOKEN}"                             # 러너 토큰

rbac:
  create: true

serviceAccount:
  create: true                                             # 러너를 위한 서비스 계정을 자동으로 생성함
  name: "gitlab-runner"             

runners:
  # 러너가 빌드 시 사용할 기본 이미지
  config: |
    [[runners]]
      request_concurrency = 10                             # 동시에 처리할 수 있는 작업수 
      [runners.kubernetes]
        namespace = "gitlab-runner"
        image = "ubuntu:22.04"
        privileged = true                                  # Docker-in-Docker(DinD) 사용 시 필요
        service_account = "gitlab-runner"                  # 러너가 생성하는 빌드 Pod 도 이 SA를 사용하도록 명시 
        # 플랫폼 자동 감지를 위해 아키텍처(x86_64-)가 없는 헬퍼 이미지를 지정합니다.
        # helper_image = "registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:latest"
           
metrics:                                                   # 0/1 READY 상태 해결을 위해 반드시 필요 (listen_address 활성화)
  enabled: true
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

### GitLabRunner-S3-ECR-Role 생성 ###
```
cat <<EOF > pod-identity-trust.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF

# 1. IAM Role 생성
aws iam create-role --role-name GitLabRunner-S3-ECR-Role --assume-role-policy-document file://pod-identity-trust.json
aws iam attach-role-policy --role-name GitLabRunner-S3-ECR-Role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
aws iam attach-role-policy --role-name GitLabRunner-S3-ECR-Role --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

```
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export CLUSTER_NAME="get-started-eks"

eksctl create podidentityassociation \
    --cluster ${CLUSTER_NAME} \
    --namespace gitlab-runner \
    --service-account-name gitlab-runner \
    --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitLabRunner-S3-ECR-Role \
    --region ${AWS_REGION}
aws eks list-pod-identity-associations --cluster-name ${CLUSTER_NAME}
```
* 생성시 오류가 발생하는 경우 기존것을 아래 명령어로 지우고 다시 생성한다.
```
aws eks delete-pod-identity-association --cluster-name ${CLUSTER_NAME} --association-id a-jn9xehzncvap8a2zv
```

생성된 파드 Identity 를 확인하다. 
```
eksctl get podidentityassociation --cluster ${CLUSTER_NAME} --region ${AWS_REGION} --namespace gitlab-runner
```

### UI 에서 인스턴스 러너 확인 ###
우측 상단의 [Admin] 버튼을 클릭한 후, 나타나는 화면의 좌측 Admin area 메뉴에서 CI/CD 하단의 Runners 를 선택한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-instance-runner.png)

## GitLab 에이전트 설정 ##

GitLab 에이전트는 쿠버네티스 환경에 최적화된 클라우드 네이티브 기반의 지속적 배포(CD) 관리 도구로, 클러스터 내부에서 GitLab 서버와 암호화된 통신 세션을 유지하며 코드 저장소의 매니페스트와 실제 운영 중인 클러스터의 상태를 실시간으로 일치시키는 핵심 엔진 역할을 수행한다. 단순히 배포 명령만 전달하는 과거의 방식에서 벗어나, 방화벽을 허물지 않고도 사설망 내부로 안전한 통로를 구축하는 CI/CD 터널링을 지원하여 파이프라인의 보안성을 극대화하며, 배포 이후에도 클러스터 내 리소스의 변동 사항이나 보안 취약점 정보를 수집하여 개발자에게 실시간으로 피드백하는 통합 운영 프록시로서의 기능을 모두 포함하고 있다. 결과적으로 이 에이전트는 인프라 관리를 코드로 자동화하는 GitOps를 실현하여 수동 배포의 위험을 제거하고, 개발자가 복잡한 인프라 설정 없이도 GitLab 대시보드에서 애플리케이션의 생명주기를 안정적으로 관리할 수 있도록 돕는 고도화된 CD 솔루션이다.

### 1. 프로젝트 생성하기 ###

좌측 메뉴에서 Projects 를 선택한 후 Create a Project 를 클릭한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/create-project-1a.png)
Create blank project 를 선택한다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-project-2.png)
아래 그림과 같이 프로젝트 속성값 들을 채우고, [Create porject] 버튼을 클릭한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-project-3.png)
my-app 프로젝트가 생성되었다. 우측 상단의 [Code] 버튼을 클릭하여 Cone with HTTP URL 을 복사한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-project-4.png)


my-app GitLab 레포지토리를 클론 한다.
```
git clone http://ec2-54-250-246-236.ap-northeast-1.compute.amazonaws.com/root/my-app.git
cd my-app
```

Git 푸시를 위한 자격증명을 등록한다. 
```
git config --global credential.helper store
touch ~/.git-credentials
chmod 600 ~/.git-credentials
echo "http://root:${PAT}@${PUBLIC_HOSTNAME}" >> ~/.git-credentials

#git remote set-url origin ${EXTERNAL_URL}/root/my-app.git
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

### 2. 에어전트 파일생성 및 푸시 ###
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

### 3. K8S 에이전트 설치 ###

my-app Project 에서 Operate > Kubernetes clusters 를 클릭한다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-1.png)
Connect a cluster를 눌러 에이전트를 등록하고,
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-2.png)
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-3.png)

아래 Helm 차트 생성 스크립트를 복사하여 get-started-eks 클러스터에 gitlab 에이전트(my-k8s-agent)를 설치한다.  
![](https://github.com/gnosia93/get-started-eks/blob/main/images/operate-k8s-4.png)

#### 4. KAS 설정 ####
GitLab 에이전트는 KAS(GitLab Agent Server)와 통신하며 ws:// 프로토콜과 주소 형식에 따라 사용 포트를 결정한다.(현재 설정으로는 80 포트를 통해 통신 시도)
KAS 는 기본적으로 로컬 통신(127.0.0.1) 에 대해서만 열려져 있기 때문에 아래 명령으로 KAS 설정을 수정한다.  
```
sudo tee -a /etc/gitlab/gitlab.rb <<EOF
# GitLab KAS Configuration
gitlab_kas['enable'] = true
gitlab_kas['listen_address'] = '0.0.0.0:8150'      # 외부 접속(EKS)을 위해 0.0.0.0 설정 (포트 명시)
gitlab_rails['gitlab_kas_external_url'] = 'ws://${PUBLIC_HOSTNAME}/-/kubernetes-agent/'   # / 필수.
EOF

sudo gitlab-ctl reconfigure
```
EC2 시스큐리티 그룹은 8150 포트에 대해서 VPC 또는 EKS 클러스터 레벨에서 오픈되어 있어야 한다. 
gitlab 에이전트 로그를 확인하여 Gitlab KAS 통신이 제대로 이뤄지는지 확인한다. 
```
kubectl rollout restart deployment/my-k8s-agent-gitlab-agent-v2 -n gitlab-agent-my-k8s-agent
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






