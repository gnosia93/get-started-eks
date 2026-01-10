## Docker Buildx 활용 ##
Docker의 Buildx는 여러 아키텍처용 이미지를 동시에 빌드하고 하나의 태그로 묶어 푸시하는 기능을 제공한다.

```
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CLUSTER_NAME="get-started-eks"
export ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ${ECR_URL}
```
```
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $ECR_URL

docker buildx create --name multi-platform-builder --use
docker buildx inspect --bootstrap

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ${ECR_URL}/${REPO_NAME}:latest \
  --push .
```

* --push: 멀티 아키텍처 이미지는 로컬 Docker 엔진에 한 번에 저장할 수 없으므로, 빌드 즉시 Amazon ECR로 올려야 한다.
* Manifest: ECR에 올라가면 하나의 태그(latest) 안에 x86_64와 arm64용 이미지가 모두 포함된 매니페스트 리스트가 생성된다.
* EKS 활용: 이제 get-started-eks 클러스터에서 Graviton(ARM) 노드를 추가하더라도, 동일한 이미지 태그를 사용하여 서비스를 배포할 수 있다.


## Gradle 'Jib' 플러그인 활용 (Docker 없이 빌드) ##
Docker 데몬이 설치되지 않은 환경(예: CI/CD 서버)에서도 멀티 아키텍처 이미지를 구울 수 있는 방법입니다.
설정 방법: build.gradle에 아래 내용을 추가합니다.
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

실행: ./gradlew jib 명령 하나로 멀티 아키텍처 이미지가 생성되어 레지스트리에 올라갑니다. Google Jib 가이드에서 더 상세한 설정을 확인할 수 있습니다.
