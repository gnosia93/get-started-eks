
## 스프링부트 어플리케이션 만들기 ##

#### spring cli 설치 ####
```
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install springboot
spring --version
```

#### 웹 어플리케이션 생성 ####
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

## Docker 이미지 생성하기 ##
```
export REPO_NAME="my-gradle-repo"

cat <<EOF > Dockerfile
FROM openjdk:17-jdk-slim
COPY build/libs/*-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
EOF
```
```
docker build -t $REPO_NAME .
```

## ECR 푸시 ## 
```
AWS_REGION="ap-northeast-2"
ECR_URL="[계정ID].dkr.ecr.${AWS_REGION}.amazonaws.com"


aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL

docker tag $REPO_NAME:latest $ECR_URL/$REPO_NAME:latest
docker push $ECR_URL/$REPO_NAME:latest
```

## 파드 생성하기 ##
