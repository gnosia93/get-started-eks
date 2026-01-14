### 1. Cloud Native Buildpacks (가장 추천) ###
   
Buildpacks는 소스 코드를 분석해서 알아서 최적화된 이미지를 만들어줍니다. Dockerfile이 없어도 됩니다.
* 특징: 보안 패치가 적용된 베이스 이미지를 알아서 선택하고, 레이어 최적화를 해줍니다.
* 사용법: pack build my-app --builder heroku/buildpacks:20 같은 명령어로 끝납니다.
* Spring Boot 유저라면: mvn spring-boot:build-image 또는 ./gradlew bootBuildImage 명령만으로 내부적으로 Buildpacks를 이용해 이미지를 즉시 생성해 줍니다.

### 2. Google Jib (Java 전용) ###
Java 개발자라면 도커 데스크탑이 설치되어 있지 않아도 이미지를 빌드할 수 있는 Google Jib이 최고입니다.
* 특징: Dockerfile 작성이나 도커 데몬 실행 없이 Maven/Gradle 설정만으로 ECR에 바로 이미지를 쏠 수 있습니다.
* 장점: 빌드 속도가 매우 빠르고 이미지 구조가 효율적입니다.

### 3. AWS App2Container (A2C) ###
AWS에서 제공하는 공식 도구로, 기존 EC2나 온프레미스 서버에서 실행 중인 앱을 분석해서 컨테이너로 바꿔줍니다.
* 특징: 실행 중인 자바(.war)나 .NET 앱을 감지하여 자동으로 Dockerfile과 EKS 배포용 YAML까지 생성해 줍니다. AWS App2Container 안내를 참고하세요 
