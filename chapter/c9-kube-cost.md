Kubecost는 쿠버네티스 클러스터 내의 리소스(CPU, 메모리, 스토리지, 네트워크) 소비량을 분석하여 실시간 요금을 추적하고 최적화 방안을 제안하는 도구입니다. AWS EKS와 긴밀하게 통합되어 있어 실무에서 필수로 쓰입니다.

1. 주요 특징
* 실시간 가시성: 어떤 서비스(Pod), 네임스페이스, 레이블이 비용을 많이 쓰는지 시각화합니다.
* AWS 연동: 실제 AWS 빌링 데이터와 연동하여 Spot 인스턴스 할인율이나 예약 인스턴스(RI) 가격을 정확히 반영합니다.
* 비용 절감 제안: "사용되지 않는 노드가 있으니 삭제하라" 또는 "Pod의 리소스 할당량(Request)을 줄이라"는 식의 가이드를 제공합니다.


### 설치 방법 ###
```
helm repo add kubecost kubecost.github.io

helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace
```
