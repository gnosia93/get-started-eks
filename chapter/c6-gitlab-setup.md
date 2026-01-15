## GitLab 설치하기 ##
com_x86_vscode 서버에 접속해서 gitlab 을 설치한다.
```
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
```
GitLab 버전 리스트를 조회한다. 
```
sudo dnf --showduplicates list gitlab-ce
```
[결과]
```
...
gitlab-ce.x86_64                                                                   17.6.5-ce.0.amazon2023                                                                      gitlab_gitlab-ce 
gitlab-ce.x86_64                                                                   17.7.0-ce.0.amazon2023                                                                      gitlab_gitlab-ce 
gitlab-ce.x86_64                                                                   17.7.1-ce.0.amazon2023                                                                      gitlab_gitlab-ce 
...                              
```
17.7.0-ce.0.amazon2023 버전을 설치한다.
```
curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
sudo EXTERNAL_URL="${EXTERNAL_URL}" dnf install -y gitlab-ce-17.7.0-ce.0.amazon2023 
sudo gitlab-ctl reconfigure
```
GitLab 은 단순한 프로그램이 아니라 PostgreSQL, Redis, Nginx, Prometheus 등 수많은 오픈소스 소프트웨어를 하나로 묶은 Omnibus 패키지 형태이다. GitLab 공식 하드웨어 요구사항에 따르면 패키지 설치에만 약 2.5GB의 저장 공간이 필요하며, 이를 다운로드하고 압축을 푸는 데 상당한 시간이 소요됩니다. 
GitLab 을 설치하고 환경을 설정하는데 5분 정도의 시간이 소요된다.

```
sudo gitlab-ctl status
```
[결과]
```
run: alertmanager: (pid 131704) 118s; run: log: (pid 130421) 159s
run: gitaly: (pid 131336) 130s; run: log: (pid 127954) 292s
run: gitlab-exporter: (pid 131391) 129s; run: log: (pid 129729) 187s
run: gitlab-kas: (pid 128348) 282s; run: log: (pid 128389) 279s
run: gitlab-workhorse: (pid 131298) 130s; run: log: (pid 129146) 207s
run: logrotate: (pid 127701) 307s; run: log: (pid 127751) 304s
run: nginx: (pid 131346) 130s; run: log: (pid 129248) 201s
run: node-exporter: (pid 131385) 129s; run: log: (pid 129362) 195s
run: postgres-exporter: (pid 131730) 117s; run: log: (pid 130631) 153s
run: postgresql: (pid 128040) 288s; run: log: (pid 128146) 285s
down: prometheus: 0s, normally up, want up; run: log: (pid 129894) 177s
run: puma: (pid 128888) 220s; run: log: (pid 128913) 219s
run: redis: (pid 127792) 301s; run: log: (pid 127801) 300s
run: redis-exporter: (pid 131412) 128s; run: log: (pid 129779) 183s
run: sidekiq: (pid 128975) 214s; run: log: (pid 129002) 213s
```

#### 참고 ####
* sudo gitlab-ctl reconfigure / restart / status / stop
* GitLab 삭제
```
sudo gitlab-ctl stop
sudo gitlab-ctl uninstall
sudo gitlab-ctl cleanse
sudo gitlab-ctl remove-accounts
sudo dnf remove -y gitlab-ce
```

### 로그인 하기 ###

![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-login-root.png)
아래 명령어로 root 계정 패스워드를 확인 후 웹브라우저를 이용하여 80 포트로 접속한다. 
```
sudo cat /etc/gitlab/initial_root_password
```

### 개인 액세스 토큰(Personal Access Token, PAT) 발급 ###

우측 상단의 아바타 아이콘을 클릭하고 [Edit profile]을 선택한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-pat-0.png)
액세스 토큰 메뉴: 왼쪽 사이드바 메뉴에서 [Personal Access Tokens]를 클릭한 후 [Add new token] 버튼을 클릭한다.  
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-pat.png)
화면상단의 Your token 을 복사한다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-pat-2.png)


## 레퍼런스 ##
* https://aws.amazon.com/ko/blogs/containers/ci-cd-with-amazon-eks-using-aws-app-mesh-and-gitlab-ci/

