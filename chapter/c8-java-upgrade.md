### 가장 권장하는 변환 시나리오 ###
단순히 AWS의 Java 업그레이드 AI를 쓰기 위해 변환하는 것이라면 아래 순서를 추천합니다.
* Gradle에서 pom.xml을 생성합니다 (터미널에서 gradle/gradlew generatePomFileForMavenPublication 실행).
* 생성된 pom.xml을 프로젝트 루트로 옮깁니다.
* IntelliJ에서 프로젝트를 다시 로드하여 Maven 프로젝트로 인식시킵니다.
* 빌드 에러가 나는 부분(주로 플러그인)을 수정합니다.
* 정상 작동 확인 후 Amazon Q Code Transformation을 가동합니다.


## 레퍼런스 ##
* https://aws.amazon.com/ko/blogs/korea/upgrade-your-java-applications-with-amazon-q-code-transformation-preview/
