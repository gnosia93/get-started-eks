
### 1. 스프링부트 앱 만들기 ###
![](https://github.com/gnosia93/get-started-eks/blob/main/images/spring-intializer.png)

아래 명령어로 스프링부트 웹 어플리케이션을 만든다.
```
spring init --dependencies=web --java-version=17 --build=gradle my-spring-app
cd my-spring-app
./gradlew clean build -x test
```

### 2. Docker 이미지 만들기 ###
로컬에서 이미지를 빌드한 후, ECR 주소를 포함한 태그를 붙여줍니다. (프로젝트 루트에 Dockerfile이 있어야 합니다.) 
```
docker build -t spring-boot-app .

docker tag spring-boot-app:latest [계정ID].dkr.ecr.ap-northeast-2.amazonaws.com/[리포지토리명]:latest
```

### 3. ECR에 이미지 푸시 ### 
```
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin [계정ID].dkr.ecr.ap-northeast-2.amazonaws.com
docker push [계정ID].dkr.ecr.ap-northeast-2.amazonaws.com/[리포지토리명]:latest
```

Dockerfile 예시
```
FROM openjdk:17-jdk-slim
# Maven은 target/*.jar, Gradle은 build/libs/*.jar 경로를 사용하세요.
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### 4. 파드 생성하기 ###
