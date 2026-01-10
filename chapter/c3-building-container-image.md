
### 1. 스프링부트 어플리케이션 만들기 ###
![](https://github.com/gnosia93/get-started-eks/blob/main/images/spring-intializer.png)

#### spring cli 설치 ####
```
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install springboot
spring --version
```

#### 웹 어플리케이션 생성 ####
```
spring init --dependencies=web --java-version=17 --build=gradle my-spring-app
cd my-spring-app
./gradlew clean build -x test
```

### 2. Docker 이미지 만들기 ###
```
cat <<EOF > Dockerfile
FROM openjdk:17-jdk-slim
COPY build/libs/*-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
EOF
```

```
docker build -t $REPO_NAME .
docker tag $REPO_NAME:latest $ECR_URL/$REPO_NAME:latest
```

### 3. ECR에 이미지 푸시 ### 
```
AWS_REGION="ap-northeast-2"
ECR_URL="[계정ID].dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="my-gradle-repo"

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
docker push $ECR_URL/$REPO_NAME:latest
```

### 4. 파드 생성하기 ###
