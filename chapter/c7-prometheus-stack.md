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
생성된 쿠버네티스 오브젝트들을 조회한다.  
```
kubectl get all -n monitoring 
```
[결과]
```
NAME                                                         READY   STATUS    RESTARTS   AGE
pod/alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          2m29s
pod/prometheus-grafana-7f9fc88457-s8s4l                      3/3     Running   0          2m36s
pod/prometheus-kube-prometheus-operator-87898cb65-85cxt      1/1     Running   0          2m36s
pod/prometheus-kube-state-metrics-857895cb8d-kp68s           1/1     Running   0          2m36s
pod/prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          2m29s
pod/prometheus-prometheus-node-exporter-87txn                1/1     Running   0          2m36s
pod/prometheus-prometheus-node-exporter-bxb8v                1/1     Running   0          2m36s
pod/prometheus-prometheus-node-exporter-dch2s                1/1     Running   0          2m35s
pod/prometheus-prometheus-node-exporter-rsqmt                1/1     Running   0          2m36s

NAME                                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/alertmanager-operated                     ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   2m29s
service/prometheus-grafana                        ClusterIP   172.20.47.128    <none>        80/TCP                       2m37s
service/prometheus-kube-prometheus-alertmanager   ClusterIP   172.20.53.163    <none>        9093/TCP,8080/TCP            2m37s
service/prometheus-kube-prometheus-operator       ClusterIP   172.20.137.118   <none>        443/TCP                      2m37s
service/prometheus-kube-prometheus-prometheus     ClusterIP   172.20.63.93     <none>        9090/TCP,8080/TCP            2m37s
service/prometheus-kube-state-metrics             ClusterIP   172.20.107.114   <none>        8080/TCP                     2m37s
service/prometheus-operated                       ClusterIP   None             <none>        9090/TCP                     2m29s
service/prometheus-prometheus-node-exporter       ClusterIP   172.20.231.227   <none>        9100/TCP                     2m37s

NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/prometheus-prometheus-node-exporter   4         4         4       4            4           kubernetes.io/os=linux   2m36s

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/prometheus-grafana                    1/1     1            1           2m36s
deployment.apps/prometheus-kube-prometheus-operator   1/1     1            1           2m36s
deployment.apps/prometheus-kube-state-metrics         1/1     1            1           2m36s

NAME                                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/prometheus-grafana-7f9fc88457                   1         1         1       2m36s
replicaset.apps/prometheus-kube-prometheus-operator-87898cb65   1         1         1       2m36s
replicaset.apps/prometheus-kube-state-metrics-857895cb8d        1         1         1       2m36s

NAME                                                                    READY   AGE
statefulset.apps/alertmanager-prometheus-kube-prometheus-alertmanager   1/1     2m29s
statefulset.apps/prometheus-prometheus-kube-prometheus-prometheus       1/1     2m29s
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

kubectl get svc -n monitoring | grep prometheus-grafana | awk '{print $4,$5}'
```
[결과]
```
ae286c7ef5ccc461a9565b5cb7863132-369961314.ap-northeast-2.elb.amazonaws.com  
```
Classic Load Balancer 가 프로비저닝 되는데 시간이 다소 걸리는 관계로 nslookup 을 통해서 DNS Resoloving 을 먼저 해 본다. 
```
nslookup a1a8724b35de34450a9c1b29705c9963-119690710.ap-northeast-2.elb.amazonaws.com
```
[결과]
```
Server:         10.0.0.2
Address:        10.0.0.2#53

Non-authoritative answer:
Name:   a1a8724b35de34450a9c1b29705c9963-119690710.ap-northeast-2.elb.amazonaws.com
Address: 43.202.181.25
Name:   a1a8724b35de34450a9c1b29705c9963-119690710.ap-northeast-2.elb.amazonaws.com
Address: 3.35.111.100
```
그라파나 admin 패스워드를 조회한다. 
```
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

## 대시보드 ##
대시보드 리스트를 확인한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/images/grafana-dashboard.png)
클러스터 대시보드를 선택하여 세부 메트릭들을 관찰한다. 
![](https://github.com/gnosia93/get-started-eks/blob/main/images/grafana-dashboard-cluster.png)



