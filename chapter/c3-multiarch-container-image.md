```
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-repo/your-app:latest --push .
```



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
