## 사전 준비 사항 ##
도커와 spring cli 을 설치한다.
```
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker $USER
newgrp docker
```
```
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install springboot
spring --version
```

## 스프링부트 어플리케이션 만들기 ##

### 웹 어플리케이션 생성 ###
```
sdk install java 17.0.9-amzn

spring init --dependencies=web --java-version=17 --type=gradle-project my-spring-app
cd my-spring-app
./gradlew clean build -x test
```
[결과]
```
Downloading https://services.gradle.org/distributions/gradle-9.2.1-bin.zip
............10%.............20%.............30%.............40%.............50%.............60%.............70%.............80%.............90%.............100%

Welcome to Gradle 9.2.1!

Here are the highlights of this release:
 - Windows ARM support
 - Improved publishing APIs
 - Better guidance for dependency verification failures

For more details see https://docs.gradle.org/9.2.1/release-notes.html

Starting a Gradle Daemon (subsequent builds will be faster)

BUILD SUCCESSFUL in 36s
6 actionable tasks: 5 executed, 1 up-to-date
Consider enabling configuration cache to speed up this build: https://docs.gradle.org/9.2.1/userguide/configuration_cache_enabling.html
```
빌드 결과 jar 를 조회한다. plain 빌드시 의존성이 제외된 jar 이다.
```
ls -la build/libs/
```
[결과]
```
total 19200
drwxrwxr-x. 2 ec2-user ec2-user       92 Jan 10 06:55 .
drwxrwxr-x. 7 ec2-user ec2-user      107 Jan 10 06:55 ..
-rw-rw-r--. 1 ec2-user ec2-user     1518 Jan 10 06:55 my-spring-app-0.0.1-SNAPSHOT-plain.jar
-rw-rw-r--. 1 ec2-user ec2-user 19655626 Jan 10 06:55 my-spring-app-0.0.1-SNAPSHOT.jar
```

### Docker 이미지 생성하기 ###
```
export REPO_NAME="my-spring-repo"

cat <<EOF > Dockerfile
FROM amazoncorretto:17-al2023-headless
COPY build/libs/*-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
EOF
```
```
docker build -t ${REPO_NAME} .
```
[결과]
```
[+] Building 11.5s (7/7) FINISHED                                                                                                                                              docker:default
 => [internal] load build definition from Dockerfile                                                                                                                                     0.0s
 => => transferring dockerfile: 210B                                                                                                                                                     0.0s
 => [internal] load metadata for docker.io/library/amazoncorretto:17-al2023-headless                                                                                                     2.1s
 => [internal] load .dockerignore                                                                                                                                                        0.0s
 => => transferring context: 2B                                                                                                                                                          0.0s
 => [internal] load build context                                                                                                                                                        0.1s
 => => transferring context: 19.66MB                                                                                                                                                     0.0s
 => [1/2] FROM docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                               6.9s
 => => resolve docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                               0.0s
 => => sha256:7c654245ff9ada8acc2efd16f00dabdf837b343b2a1b7ecade0a56257dc2695d 1.38kB / 1.38kB                                                                                           0.0s
 => => sha256:7a481df3b0f0e840550218932ab8be5a28fdd6a9aa383937a561ec2aa0ad9378 2.40kB / 2.40kB                                                                                           0.0s
 => => sha256:f0d8a57b0a961dc24c52321274c89319998d2371a5c75edf34df5d320f6cc484 53.99MB / 53.99MB                                                                                         1.2s
 => => sha256:50624870b4839f57d05ceefe4aad9feeb931c8e783bbe9bf92c47c8857359d7e 82.35MB / 82.35MB                                                                                         5.8s
 => => sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e 2.69kB / 2.69kB                                                                                           0.0s
 => => extracting sha256:f0d8a57b0a961dc24c52321274c89319998d2371a5c75edf34df5d320f6cc484                                                                                                1.2s
 => => extracting sha256:50624870b4839f57d05ceefe4aad9feeb931c8e783bbe9bf92c47c8857359d7e                                                                                                0.9s
 => [2/2] COPY build/libs/*-SNAPSHOT.jar app.jar                                                                                                                                         2.4s
 => exporting to image                                                                                                                                                                   0.1s
 => => exporting layers                                                                                                                                                                  0.1s
 => => writing image sha256:a509da8610c8ee46e45a228f2f0fe12428139b0b645d8277d6d9b8c2b9ea6027                                                                                             0.0s
 => => naming to docker.io/library/my-spring-repo      
```

### ECR 푸시 ### 
```
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CLUSTER_NAME="get-started-eks"
export ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ${ECR_URL}

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
```
[결과]
```
WARNING! Your password will be stored unencrypted in /home/ec2-user/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```
태깅후 이미지 리스트를 조회한다. 
```
docker tag ${REPO_NAME}:latest ${ECR_URL}/${REPO_NAME}:latest
docker images
```
[결과]
```
REPOSITORY                                                         TAG       IMAGE ID       CREATED         SIZE
my-spring-repo                                                     latest    a509da8610c8   5 minutes ago   395MB
499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo   latest    a509da8610c8   5 minutes ago   395MB
```
ecr 에 푸시한다. 
```
aws ecr create-repository \
    --repository-name my-spring-repo --region ${AWS_REGION}

docker push ${ECR_URL}/${REPO_NAME}:latest
```
[결과]
```
2951e72c68fe: Pushed 
2a6676ebc424: Pushed 
6beb63c27303: Pushed 
latest: digest: sha256:079ebf5a917572664237bf0ca56bf2f5694aab658227245d1be9daacafd96a3d size: 953
```
AWS ecr 에 등록된 것을 확인할 수 있다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/images/ecr-images.png)

## 스케줄링 하기 ##
```
cat <<EOF > my-spring-app.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-spring-app
  labels:
    app: spring-boot
spec:
  replicas: 4
  selector:
    matchLabels:
      app: spring-boot
  template:
    metadata:
      labels:
        app: spring-boot
    spec:
      containers:
      - name: spring-boot-container
        image: ${ECR_URL}/${REPO_NAME}:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl apply -f my-spring-app.yaml  
```
스케줄링된 Pod 리스트를 확인한다. 
```
kubectl get pods -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.containerStatuses[0].state.waiting.reason,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp,NODE:.spec.nodeName"
```
[결과]
```
NAME                             READY   STATUS             RESTARTS   AGE                    NODE
my-spring-app-7b5f5f6577-7sn94   false   CrashLoopBackOff   6          2026-01-10T07:27:58Z   ip-10-0-10-26.ap-northeast-1.compute.internal
my-spring-app-7b5f5f6577-8pznf   false   CrashLoopBackOff   6          2026-01-10T07:27:58Z   ip-10-0-2-185.ap-northeast-1.compute.internal
my-spring-app-7b5f5f6577-khdd4   true    <none>             0          2026-01-10T07:27:58Z   ip-10-0-11-80.ap-northeast-1.compute.internal
my-spring-app-7b5f5f6577-pjplh   true    <none>             0          2026-01-10T07:27:58Z   ip-10-0-2-53.ap-northeast-1.compute.internal
```
2개의 Pod 가 false 상태인 이유는 X86 도커 이미지가 ARM 노드에 스케줄링 되었기 때문이다. 이를 해결하기 위해서는 X86 노드에만 스케줄링 하거나 도커 이미지를 멀티 아키텍처로 만들어야 한다. 

```
kubectl get nodes -L kubernetes.io/arch
```
[결과]
```
NAME                                            STATUS   ROLES    AGE   VERSION               ARCH
ip-10-0-10-26.ap-northeast-1.compute.internal   Ready    <none>   17h   v1.34.2-eks-ecaa3a6   arm64
ip-10-0-11-80.ap-northeast-1.compute.internal   Ready    <none>   17h   v1.34.2-eks-ecaa3a6   amd64
ip-10-0-2-185.ap-northeast-1.compute.internal   Ready    <none>   17h   v1.34.2-eks-ecaa3a6   arm64
ip-10-0-2-53.ap-northeast-1.compute.internal    Ready    <none>   17h   v1.34.2-eks-ecaa3a6   amd64
```



