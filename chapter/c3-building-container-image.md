
1. Spring Boot JAR 빌드
먼저 프로젝트 루트 경로에서 애플리케이션 실행 파일인 JAR를 생성합니다.
### 스프링 부트 어플리케이션 만들기 ###


### Docker 이미지 빌드 및 태그 설정 ###
로컬에서 이미지를 빌드한 후, ECR 주소를 포함한 태그를 붙여줍니다. (프로젝트 루트에 Dockerfile이 있어야 합니다.) 
bash
# 로컬 이미지 빌드
docker build -t spring-boot-app .

# ECR용 태그 추가 (계정ID와 리포지토리명을 본인 환경에 맞게 수정)
docker tag spring-boot-app:latest [계정ID].dkr.ecr.ap-northeast-2.amazonaws.com/[리포지토리명]:latest
코드를 사용할 때는 주의가 필요합니다.

### 3. AWS ECR 로그인 인증 ### 
도커가 ECR에 이미지를 올릴 수 있도록 AWS CLI를 통해 인증 토큰을 전달합니다. (상세 내용은 AWS CLI v2 로그인 가이드를 참고하세요.)
bash
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin [계정ID].dkr.ecr.ap-northeast-2.amazonaws.com
코드를 사용할 때는 주의가 필요합니다.


### 4. ECR에 이미지 푸시 ### 
마지막으로 태깅된 이미지를 AWS 클라우드로 전송합니다. 
bash
docker push [계정ID].dkr.ecr.ap-northeast-2.amazonaws.com/[리포지토리명]:latest
코드를 사용할 때는 주의가 필요합니다.

[참고] Dockerfile 예시
프로젝트 루트 폴더에 아래 내용의 Dockerfile 파일을 미리 생성해 두어야 빌드가 가능합니다. 
dockerfile
FROM openjdk:17-jdk-slim
# Maven은 target/*.jar, Gradle은 build/libs/*.jar 경로를 사용하세요.
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
