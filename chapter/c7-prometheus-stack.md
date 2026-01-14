프로메테우스 스택(kube-prometheus-stack)은 쿠버네티스 환경을 모니터링하기 위해 필요한 여러 도구(프로메테우스, 그라파나, 알람매니저 등)를 하나로 묶어놓은 종합 선물 세트 같은 오픈 소스 프로젝트이다. 원래 이 도구들을 따로 설치하려면 설정이 매우 복잡하지만, 스택을 사용하면 Helm 차트 하나로 모든 구성을 자동화할 수 있다.

### 스택의 구성 요소 ###
* Prometheus (프로메테우스): 메트릭 데이터를 수집하고 저장하는 '두뇌' 역할.
* Grafana (그라파나): 수집된 데이터를 예쁜 그래프나 대시보드로 시각화.
* Alertmanager (알람매니저): 서버 다운 등 문제가 생기면 슬랙(Slack)이나 이메일로 알림.
* Prometheus Operator (오퍼레이터): 쿠버네티스 안에서 프로메테우스 설정을 관리하고 자동으로 업데이트해 주는 관리자.
* Exporters (익스포터): 서버의 CPU/메모리 상태나 쿠버네티스 객체 상태 정보를 프로메테우스가 읽을 수 있게 변환해 주는 도구. 

## [Prometheus Stack 설치](https://github.com/prometheus-operator/kube-prometheus) ##
```
helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus/kube-prometheus-stack \
    --create-namespace --namespace monitoring 
```
생성된 파드들을 조회한다. 
```
kubectl get pods -l "release=prometheus" -n monitoring 
```
[결과]
```
NAME                                                  READY   STATUS    RESTARTS   AGE
prometheus-kube-prometheus-operator-95f6bb89f-8957b   1/1     Running   0          10m
prometheus-kube-state-metrics-66f9f5bf55-zg5bx        1/1     Running   0          10m
prometheus-prometheus-node-exporter-hp42x             1/1     Running   0          10m
prometheus-prometheus-node-exporter-hs79c             1/1     Running   0          10m
```

#### 1. 그라파나 서비스 외부 노출 #### 
![](https://github.com/gnosia93/training-on-eks/blob/main/chapter/images/prometheus-grafana.png)

그라파나 서비스를 외부로 노출 시키고, admin 패스워드를 확인후 로그인한다. 서비스의 loadBalancerSourceRanges 필드를 이용하면 출발지 주소를 제한할 수 있다.  
```
kubectl patch svc prometheus-grafana -n monitoring -p '{
  "spec": {
    "type": "LoadBalancer",
    "loadBalancerSourceRanges": ["122.36.213.114/32"]        
  }
}'

kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
kubectl get svc -n monitoring | grep prometheus-grafana | awk '{print $4,$5}'
```
[결과]
```
ae286c7ef5ccc461a9565b5cb7863132-369961314.ap-northeast-2.elb.amazonaws.com  
```
