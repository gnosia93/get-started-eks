## Gitlab 설치하기 ##
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
```
curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
sudo EXTERNAL_URL="${EXTERNAL_URL}" sudo dnf install -y gitlab-ce
sudo gitlab-ctl reconfigure
```

* sudo gitlab-ctl reconfigure / restart / status / stop
* sudo yum remove gitlab-ce

## 로그인 하기 ##

![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-login-root.png)
root 계정의 패스워드를 확인후 웹브라우저를 이용하여 80 포트로 접속한다. 
```
sudo cat /etc/gitlab/initial_root_password
```

## 개인 액세스 토큰(Personal Access Token, PAT) 발급 ##

* GitLab 로그인: 관리자(Admin) 권한이 있는 계정으로 접속한다.
* 프로필 설정 이동: 오른쪽 상단 본인 아바타 아이콘을 클릭하고 [Edit profile]을 선택한다.
* 액세스 토큰 메뉴: 왼쪽 사이드바 메뉴에서 [Personal Access Tokens]를 클릭한다.
* 신규 토큰 추가: [Add new token] 버튼을 클릭한다.
  
![](https://github.com/gnosia93/get-started-eks/blob/main/images/gitlab-pat.png)
화면상단의 Personal Access Token 을 복사한다. 
