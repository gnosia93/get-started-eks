### k6 설치 ###
vscode 서버에서 k6 를 설치한다.
```
# 1. GPG 키 가져오기 (패키지 변조 방지)
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
     --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69

# 2. k6 레포지토리 등록
echo "[k6]
name=k6
baseurl=https://dl.k6.io\$basearch
enabled=1
gpgcheck=1
gpgkey=https://dl.k6.io" | sudo tee /etc/yum.repos.d/k6.repo

# 3. 설치 진행
sudo dnf install k6 -y
```
