1. Cloud Native Buildpacks (가장 추천)
Buildpacks는 소스 코드를 분석해서 알아서 최적화된 이미지를 만들어줍니다. Dockerfile이 없어도 됩니다.
특징: 보안 패치가 적용된 베이스 이미지를 알아서 선택하고, 레이어 최적화를 해줍니다.
사용법: pack build my-app --builder heroku/buildpacks:20 같은 명령어로 끝납니다.
Spring Boot 유저라면: mvn spring-boot:build-image 또는 ./gradlew bootBuildImage 명령만으로 내부적으로 Buildpacks를 이용해 이미지를 즉시 생성해 줍니다.
