## Docker Buildx 활용 ##
Docker의 Buildx는 여러 아키텍처용 이미지를 동시에 빌드하고 하나의 태그로 묶어 푸시하는 기능을 제공한다.

```
cd ~/my-spring-app

docker buildx create --name multi-arch-builder --use
docker buildx inspect --bootstrap
```
[결과]
```
[+] Building 6.7s (1/1) FINISHED                                                                                                                                                             
 => [internal] booting buildkit                                                                                                                                                         6.7s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                                      5.3s
 => => creating container buildx_buildkit_multi-arch-builder0                                                                                                                           1.5s
Name:          multi-arch-builder
Driver:        docker-container
Last Activity: 2026-02-06 03:27:47 +0000 UTC

Nodes:
Name:      multi-arch-builder0
Endpoint:  unix:///var/run/docker.sock
Status:    running
Buildkit:  v0.27.1
Platforms: linux/amd64, linux/amd64/v2, linux/amd64/v3, linux/amd64/v4, linux/386
Labels:
 org.mobyproject.buildkit.worker.executor:         oci
 org.mobyproject.buildkit.worker.hostname:         b260953d2a87
 org.mobyproject.buildkit.worker.network:          host
 org.mobyproject.buildkit.worker.oci.process-mode: sandbox
 org.mobyproject.buildkit.worker.selinux.enabled:  false
 org.mobyproject.buildkit.worker.snapshotter:      overlayfs
GC Policy rule#0:
 All:           false
 Filters:       type==source.local,type==exec.cachemount,type==source.git.checkout
 Keep Duration: 48h0m0s
GC Policy rule#1:
 All:           false
 Keep Duration: 1440h0m0s
 Keep Bytes:    2.794GiB
GC Policy rule#2:
 All:        false
 Keep Bytes: 2.794GiB
GC Policy rule#3:
 All:        true
 Keep Bytes: 2.794GiB
```
방금 생성한 빌드를 이용하여 도커 멀티 아키텍처 이미지를 생성하고 ecr 에 푸시한다.
```
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${ECR_URL}/${REPO_NAME}:latest \
  --push .
```

* --push: 멀티 아키텍처 이미지는 로컬 Docker 엔진에 한 번에 저장할 수 없으므로, 빌드 즉시 Amazon ECR로 올려야 한다.
* Manifest: ECR에 올라가면 하나의 태그(latest) 안에 x86_64와 arm64용 이미지가 모두 포함된 매니페스트 리스트가 생성된다.

[결과]
```
[+] Building 16.4s (11/11) FINISHED                                                                                                                                  docker-container:multi-arch-builder
 => [internal] load build definition from Dockerfile                                                                                                                                                0.0s
 => => transferring dockerfile: 210B                                                                                                                                                                0.0s
 => [linux/arm64 internal] load metadata for docker.io/library/amazoncorretto:17-al2023-headless                                                                                                    2.0s
 => [linux/amd64 internal] load metadata for docker.io/library/amazoncorretto:17-al2023-headless                                                                                                    2.1s
 => [internal] load .dockerignore                                                                                                                                                                   0.0s
 => => transferring context: 2B                                                                                                                                                                     0.0s
 => [linux/arm64 1/2] FROM docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                              4.0s
 => => resolve docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                                          0.0s
 => => sha256:fbc1f0f8116a0bb21d1c9c51a56e781e91c8eb8f90fb336932558669a3f41a6a 81.77MB / 81.77MB                                                                                                    3.0s
 => => sha256:2de128a65b40f541240900d3ef927c69205504fb73b977065e0eaa128c1e3777 52.87MB / 52.87MB                                                                                                    1.9s
 => => extracting sha256:2de128a65b40f541240900d3ef927c69205504fb73b977065e0eaa128c1e3777                                                                                                           1.1s
 => => extracting sha256:fbc1f0f8116a0bb21d1c9c51a56e781e91c8eb8f90fb336932558669a3f41a6a                                                                                                           0.9s
 => [linux/amd64 1/2] FROM docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                              4.4s
 => => resolve docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                                          0.0s
 => => sha256:50624870b4839f57d05ceefe4aad9feeb931c8e783bbe9bf92c47c8857359d7e 82.35MB / 82.35MB                                                                                                    2.3s
 => => sha256:f0d8a57b0a961dc24c52321274c89319998d2371a5c75edf34df5d320f6cc484 53.99MB / 53.99MB                                                                                                    2.3s
 => => extracting sha256:f0d8a57b0a961dc24c52321274c89319998d2371a5c75edf34df5d320f6cc484                                                                                                           0.9s
 => => extracting sha256:50624870b4839f57d05ceefe4aad9feeb931c8e783bbe9bf92c47c8857359d7e                                                                                                           1.0s
 => [internal] load build context                                                                                                                                                                   0.1s
 => => transferring context: 19.66MB                                                                                                                                                                0.1s
 => [linux/arm64 2/2] COPY build/libs/*-SNAPSHOT.jar app.jar                                                                                                                                        5.9s
 => [linux/amd64 2/2] COPY build/libs/*-SNAPSHOT.jar app.jar                                                                                                                                        5.5s
 => exporting to image                                                                                                                                                                              4.3s
 => => exporting layers                                                                                                                                                                             0.5s
 => => exporting manifest sha256:699fcccfee13b4117310864de76e0258bc411c71c4c9c8f068e515e0e2090a98                                                                                                   0.0s
 => => exporting config sha256:08137335be92bd1727573c2c2cca0dcd10d6ebefb902793a104c8ebd3f16c882                                                                                                     0.0s
 => => exporting attestation manifest sha256:c80e913d766cc79372a67c0467edac9bb03fa43304bec858e5c03a06001f1a7c                                                                                       0.0s
 => => exporting manifest sha256:63c8089fb350bed58cfb1544e75a2ec308380c25ac7b975995bee71e8337f6b9                                                                                                   0.0s
 => => exporting config sha256:31dee71c3b15270ad172efb7a08b61dfd221a3884f3c1bfb78bc4750826cd218                                                                                                     0.0s
 => => exporting attestation manifest sha256:d84b64d4feb493c721d5c1622bcd8523afee4863416be6cb2b4aafda86ff3911                                                                                       0.0s
 => => exporting manifest list sha256:a093e1287efb94c08debc16ccc1eb507ab94a976fbdb44d614e7c1754580e2fb                                                                                              0.0s
 => => pushing layers                                                                                                                                                                               2.3s
 => => pushing manifest for 499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo:latest@sha256:a093e1287efb94c08debc16ccc1eb507ab94a976fbdb44d614e7c1754580e2fb                         1.4s
 => [auth] sharing credentials for 499514681453.dkr.ecr.ap-northeast-1.amazonaws.com   
```

### 이미지 확인 ###
```
docker buildx imagetools inspect ${ECR_URL}/${REPO_NAME}:latest
```
[결과]
```
 docker buildx imagetools inspect ${ECR_URL}/${REPO_NAME}:latest
Name:      499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo:latest
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:a093e1287efb94c08debc16ccc1eb507ab94a976fbdb44d614e7c1754580e2fb
           
Manifests: 
  Name:        499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo:latest@sha256:699fcccfee13b4117310864de76e0258bc411c71c4c9c8f068e515e0e2090a98
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64
               
  Name:        499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo:latest@sha256:63c8089fb350bed58cfb1544e75a2ec308380c25ac7b975995bee71e8337f6b9
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64
               
  Name:        499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo:latest@sha256:c80e913d766cc79372a67c0467edac9bb03fa43304bec858e5c03a06001f1a7c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.digest: sha256:699fcccfee13b4117310864de76e0258bc411c71c4c9c8f068e515e0e2090a98
    vnd.docker.reference.type:   attestation-manifest
               
  Name:        499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo:latest@sha256:d84b64d4feb493c721d5c1622bcd8523afee4863416be6cb2b4aafda86ff3911
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.type:   attestation-manifest
    vnd.docker.reference.digest: sha256:63c8089fb350bed58cfb1544e75a2ec308380c25ac7b975995bee71e8337f6b9
```
unknown/unknown (Attestation): 이건 에러가 아니라, 최신 buildx가 빌드 과정의 보안/이력 정보를 담은 Sbom/Provenance Attestation 데이터를 함께 푸시한 것이다.

### 파드 재시작 하기 ###
rollout restart를 쓰면 배포 전략(Strategy)에 따라 점진적으로 교체하므로 서비스 안정성이 훨씬 높다.
```
kubectl rollout restart deployment my-spring-app
kubectl rollout status deployment my-spring-app

kubectl get pods
```
```
NAME                             READY   STATUS    RESTARTS       AGE
my-spring-app-7b5f5f6577-7sn94   1/1     Running   19 (10m ago)   77m
my-spring-app-7b5f5f6577-8pznf   1/1     Running   19 (10m ago)   77m
my-spring-app-7b5f5f6577-khdd4   1/1     Running   0              77m
my-spring-app-7b5f5f6577-pjplh   1/1     Running   0              77m
```

## Native 빌드하기 ##
에뮬레이션(QEMU) 방식은 명령어를 가상으로 변환하기 때문에 최대 10배 이상 느려질 수 있다. 네이티브 빌드를 구성하기 위해서 원격 빌드 노드로 추가한다.

### ssh 설정 ###
* com_x86_vscode 에서 ssh 키를 생성한다.
```
uname -m
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub
```
* 퍼블릭 키를 복사해서 Graviton 서버의 ~/.ssh/authorized_keys 파일 끝에 붙여 넣는다.
```
echo "<퍼블릭 키>" | tee -a ~/.ssh/authorized_keys
```
### Graviton 서버에도 도커를 설치 ###
```
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker $USER
newgrp docker
```


### native-builder 만들기 ###
com_x86_vscode 에서 네이티브 빌더를 만든다. 이때 리모트 graviton 서버에는 docker 데몬이 설치되어있어야 하며, 빌드 엔진(buildkitd/buildctl) 또한 설치되어야 한다. 여기서는 --driver docker-container 을 사용하여 네이티브 빌더를 만들도록 한다. 이 빌드 전용 컨테이너는 buildctl과 더불어 필요한 도구가 모두 설치되어 있다. 즉 리모트 graviton 서버에 moby/buildkit 도커 이미지가 실행되는 것이다. (참고, buildctl 의 Amazon Linux 2023 설치 버전을 찾는게 쉽지 않다)    
```
GRAVITON_PRIV=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=code-server-graviton" \
           "Name=instance-state-name,Values=running" \
           --query "Reservations[*].Instances[*].{DNS:PrivateDnsName}" \
           --output text)
echo ${GRAVITON_PRIV}

docker buildx create --name native-builder \
  --driver docker-container --platform linux/arm64 \
  ssh://ec2-user@ip-10-0-0-224.ap-northeast-1.compute.internal

docker buildx create --name native-builder --append \
  --driver docker-container --platform linux/amd64 \
  unix:///var/run/docker.sock

docker buildx inspect --bootstrap
docker buildx ls
```
[결과]
```
NAME/NODE             DRIVER/ENDPOINT                                              STATUS  BUILDKIT PLATFORMS
multi-arch-builder    docker-container                                                              
  multi-arch-builder0 unix:///var/run/docker.sock                                  running v0.26.2  linux/amd64, linux/amd64/v2, linux/amd64/v3, linux/amd64/v4, linux/386
native-builder *      docker-container                                                              
  native-builder0     ssh://ec2-user@ip-10-0-0-224.ap-northeast-1.compute.internal running v0.26.2  linux/arm64*, linux/arm/v7, linux/arm/v6
  native-builder1     unix:///var/run/docker.sock                                  running v0.26.2  linux/amd64*, linux/amd64/v2, linux/amd64/v3, linux/amd64/v4, linux/386
default               docker                                                                        
  default             default                                                      running v0.12.5  linux/amd64, linux/amd64/v2, linux/amd64/v3, linux/amd64/v4, linux/386
```

이미지를 만들어서 푸쉬한다. 이미지는 x86과 그라비톤 서버에서 동시에 빌드된다.
```
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${ECR_URL}/${REPO_NAME}:latest \
  --push .
```
[결과]
```
[+] Building 10.6s (16/16) FINISHED                                                                                                                                                                        docker-container:native-builder
 => [internal] load build definition from Dockerfile                                                                                                                                                                                  0.0s
 => => transferring dockerfile: 210B                                                                                                                                                                                                  0.0s
 => [internal] load build definition from Dockerfile                                                                                                                                                                                  0.0s
 => => transferring dockerfile: 210B                                                                                                                                                                                                  0.0s
 => [linux/amd64 internal] load metadata for docker.io/library/amazoncorretto:17-al2023-headless                                                                                                                                      2.0s
 => [linux/arm64 internal] load metadata for docker.io/library/amazoncorretto:17-al2023-headless                                                                                                                                      2.0s
 => [internal] load .dockerignore                                                                                                                                                                                                     0.0s
 => => transferring context: 2B                                                                                                                                                                                                       0.0s
 => [internal] load build context                                                                                                                                                                                                     0.1s
 => => transferring context: 19.66MB                                                                                                                                                                                                  0.1s
 => [linux/arm64 1/2] FROM docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                                                                3.4s
 => => resolve docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                                                                            0.0s
 => => sha256:fbc1f0f8116a0bb21d1c9c51a56e781e91c8eb8f90fb336932558669a3f41a6a 81.77MB / 81.77MB                                                                                                                                      1.4s
 => => sha256:2de128a65b40f541240900d3ef927c69205504fb73b977065e0eaa128c1e3777 52.87MB / 52.87MB                                                                                                                                      1.5s
 => => extracting sha256:2de128a65b40f541240900d3ef927c69205504fb73b977065e0eaa128c1e3777                                                                                                                                             1.0s
 => => extracting sha256:fbc1f0f8116a0bb21d1c9c51a56e781e91c8eb8f90fb336932558669a3f41a6a                                                                                                                                             0.9s
 => [internal] load .dockerignore                                                                                                                                                                                                     0.0s
 => => transferring context: 2B                                                                                                                                                                                                       0.0s
 => [internal] load build context                                                                                                                                                                                                     0.1s
 => => transferring context: 19.66MB                                                                                                                                                                                                  0.1s
 => [linux/amd64 1/2] FROM docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                                                                3.6s
 => => resolve docker.io/library/amazoncorretto:17-al2023-headless@sha256:0f82e79736cc6b8dd0763db1708aaa2e4d7993b41680a33536098805912d6e2e                                                                                            0.0s
 => => sha256:50624870b4839f57d05ceefe4aad9feeb931c8e783bbe9bf92c47c8857359d7e 82.35MB / 82.35MB                                                                                                                                      1.7s
 => => sha256:f0d8a57b0a961dc24c52321274c89319998d2371a5c75edf34df5d320f6cc484 53.99MB / 53.99MB                                                                                                                                      1.6s
 => => extracting sha256:f0d8a57b0a961dc24c52321274c89319998d2371a5c75edf34df5d320f6cc484                                                                                                                                             1.0s
 => => extracting sha256:50624870b4839f57d05ceefe4aad9feeb931c8e783bbe9bf92c47c8857359d7e                                                                                                                                             0.9s
 => [linux/arm64 2/2] COPY build/libs/*-SNAPSHOT.jar app.jar                                                                                                                                                                          2.7s
 => [linux/amd64 2/2] COPY build/libs/*-SNAPSHOT.jar app.jar                                                                                                                                                                          2.3s
 => exporting to image                                                                                                                                                                                                                1.9s
 => => exporting layers                                                                                                                                                                                                               0.5s
 => => exporting manifest sha256:dc571ce2b59e01b60963b6741f827bbf6789db902f5b12e80de02f20c9863690                                                                                                                                     0.0s
 => => exporting config sha256:5596e8860371456438057944e37d521af264390c3e9acede43f32a449ba243e0                                                                                                                                       0.0s
 => => exporting attestation manifest sha256:cf01b7f0046c2355cf73f093b7c7aac6417c58552f700aff8e02676b5376173f                                                                                                                         0.0s
 => => exporting manifest list sha256:a2c7bfdde8951d63121d8f7232e4930a9b1f7cda9d2e80987f765853d8e87313                                                                                                                                0.0s
 => => pushing layers                                                                                                                                                                                                                 0.5s
 => => pushing manifest for 499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo                                                                                                                                          0.9s
 => exporting to image                                                                                                                                                                                                                1.9s
 => => exporting layers                                                                                                                                                                                                               0.5s
 => => exporting manifest sha256:daf1d4026e35ffed1250cf3c7f353a926662a4b03323c4873a9372700e348983                                                                                                                                     0.0s
 => => exporting config sha256:f0bcb954f3564b1040c1e68cf9fe0cbe6441b591b3998f3a0e2bf260135e4a1d                                                                                                                                       0.0s
 => => exporting attestation manifest sha256:939b7d1c132ebcf7b12e9eb852e5b5ce170f388ff7235150067cb6afcb0a0479                                                                                                                         0.0s
 => => exporting manifest list sha256:490bd90feba79880cf7aa40ce4810453df3d22855b192a2bdae8b0565f8c758d                                                                                                                                0.0s
 => => pushing layers                                                                                                                                                                                                                 0.5s
 => => pushing manifest for 499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo                                                                                                                                          0.8s
 => [auth] sharing credentials for 499514681453.dkr.ecr.ap-northeast-1.amazonaws.com                                                                                                                                                  0.0s
 => merging manifest list 499514681453.dkr.ecr.ap-northeast-1.amazonaws.com/my-spring-repo:latest       
```


## 참고 - [Gradle 'Jib'](https://github.com/GoogleContainerTools/jib/blob/master/jib-gradle-plugin/README.md) 플러그인 활용 (Docker 없이 빌드) ##
Docker 데몬이 설치되지 않은 환경(예: CI/CD 서버)에서도 멀티 아키텍처 이미지를 구울 수 있는 방법이다.
build.gradle에 아래 내용을 추가한다.
```
gradle
jib {
    from {
        image = "eclipse-temurin:17-jre" // 멀티 아키텍처 지원 베이스 이미지
    }
    to {
        image = "your-repo/your-app"
    }
    container {
        platforms {
            platform { architecture = "amd64"; os = "linux" }
            platform { architecture = "arm64"; os = "linux" }
        }
    }
}
```
./gradlew jib 명령 하나로 멀티 아키텍처 이미지가 생성되어 레지스트리에 올라간다(Google Jib 가이드에서 더 상세한 설정을 확인)

## 레퍼런스 ##
* https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/remote-buildkit-ec2

