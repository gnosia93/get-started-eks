## 아파치 ab 를 활용한 성능 측정 ##

#### apache bench (ab) 를 설치한다 ####
```
sudo dnf update -y
sudo dnf install httpd-tools -y
```

#### ALB URL 를 테스트 하다 ####
```
ALB_URL=$(aws cloudformation describe-stacks --stack-name graviton-mig-stack \
  --query "Stacks[0].Outputs[?OutputKey=='ALBURL'].OutputValue" \
  --output text | xargs)
echo "${ALB_URL}"

ab -t 300 -c 50 -n 1000000 "http://${ALB_URL}/"
```
* -n(총 요청수)을 넉넉히 잡고, -t(시간)를 300초로 설정
* -c(동시 접속자)는 서버 사양에 맞게 조정 (예: 50명)


## Cloudwatch ##
Graviton(ARM64)과 기존 인스턴스(x86)의 성능 차이를 객관적으로 비교하려면, ALB가 각 타겟 그룹(TG)별로 쌓는 CloudWatch 메트릭을 대조해야 한다.
AWS CloudWatch ALB 지표 가이드를 바탕으로 꼭 확인해야 할 3가지 핵심 지표 이다.

### 1. 응답 속도 비교 (TargetResponseTime) ###
가장 중요한 지표로, Graviton이 기존 대비 얼마나 빠른지(혹은 느린지) 평균값과 P99(상위 1% 지연 시간)를 확인한다.
* Metric Name: TargetResponseTime
* Dimensions: TargetGroup 별로 필터링하여 비교
* 확인 포인트: 동일한 트래픽 비중 대비 Graviton TG의 응답 시간이 더 낮게 유지되는지 확인한다.

### 2. 처리량 및 에러율 (RequestCount & HTTPCode_Target) ###
Graviton에서 애플리케이션이 안정적으로 동작하는지 확인한다.
* RequestCount: 가중치 설정(예: 8:2)대로 요청이 들어오고 있는지 확인.
* HTTPCode_Target_5XX_Count: Graviton TG에서만 에러가 발생하지 않는지 확인.

### 3. CPU 사용량 및 비용 효율 (CPUUtilization) ####
인스턴스 자체의 부하를 비교한다.
* Metric Name: CPUUtilization (AWS/EC2 네임스페이스)
* 비교 방법: Graviton은 보통 x86보다 가성비가 좋으므로, 비슷한 응답 속도에서 CPU 사용량이 더 낮은지 확인하는 것이 핵심이다.



