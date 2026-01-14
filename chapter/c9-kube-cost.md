Kubecost는 쿠버네티스 클러스터 내의 리소스(CPU, 메모리, 스토리지, 네트워크) 소비량을 분석하여 실시간 요금을 추적하고 최적화 방안을 제안하는 도구로 다음과 같은 특징을 가지고 있다.

* 실시간 가시성: 어떤 서비스(Pod), 네임스페이스, 레이블이 비용을 많이 쓰는지 시각화.
* AWS 연동: 실제 AWS 빌링 데이터와 연동하여 Spot 인스턴스 할인율이나 예약 인스턴스(RI) 가격을 정확히 반영.
* 비용 절감 제안: "사용되지 않는 노드가 있으니 삭제하라" 또는 "Pod의 리소스 할당량(Request)을 줄이라"는 식의 가이드를 제공.

### [설치 방법](https://github.com/kubecost/kubecost) ###
```
helm install kubecost \
  --repo https://kubecost.github.io/kubecost kubecost \
  --namespace kubecost --create-namespace \
  --set global.clusterId=${CLUSTER_NAME}
```
```
kubectl get pods --namespace kubecost
```
[결과]
```
NAME                                           READY   STATUS    RESTARTS   AGE
kubecost-aggregator-0                          0/1     Pending   0          19s
kubecost-cloud-cost-b99f5ccd-5c6ss             0/1     Pending   0          19s
kubecost-cluster-controller-7c85cd6774-57lvn   1/1     Running   0          19s
kubecost-finopsagent-df8678dfd-7smdt           0/1     Pending   0          19s
kubecost-forecasting-69bb7667d9-whrzj          0/1     Running   0          19s
kubecost-frontend-85b98c5f5-ng8p4              1/1     Running   0          19s
kubecost-local-store-84c99cddd6-nxmsh          0/1     Pending   0          19s
kubecost-network-costs-84wlc                   1/1     Running   0          19s
kubecost-network-costs-9256l                   1/1     Running   0          19s
kubecost-network-costs-mkf28                   1/1     Running   0          19s
kubecost-network-costs-zfgqz                   1/1     Running   0          20s
```
kubecost 프런트엔드 서비스를 조회한다.
```
kubectl get svc kubecost-frontend -n kubecost
```
[결과]
```
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubecost-frontend   ClusterIP   172.20.44.175   <none>        9090/TCP   4m53s
```

### Kubecost Ingress 설정 ###
```
cat <<EOF | kubectl apply -f - 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubecost-ingress
  namespace: kubecost
  annotations:
    # ALB 생성 및 인터넷 노출 설정
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    # 아래 설정을 추가하여 출발지 IP를 제한합니다 (쉼표로 구분하여 여러 개 등록 가능)
    alb.ingress.kubernetes.io/inbound-cidrs: "122.36.213.114/32, 1.2.3.4/32"
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubecost-frontend
                port:
                  number: 9090
EOF
```
인그레스를 조회한다. 
```
kubectl get ingress -n kubecost
```
[결과]
```
NAME               CLASS   HOSTS   ADDRESS                                                                        PORTS   AGE
kubecost-ingress   alb     *       k8s-kubecost-kubecost-2e8ad5d25f-2007371535.ap-northeast-2.elb.amazonaws.com   80      11s
```

DNS 주소가 리졸링 되는지 확인한다. ALB 가 준비되어 DNS 주소가 활성화 될때 까지 다소 시간이 소요된다. 
```
nslookup k8s-kubecost-kubecost-2e8ad5d25f-2007371535.ap-northeast-2.elb.amazonaws.com
```
[결과]
```
Server:         10.0.0.2
Address:        10.0.0.2#53

Non-authoritative answer:
Name:   k8s-kubecost-kubecost-2e8ad5d25f-2007371535.ap-northeast-2.elb.amazonaws.com
Address: 15.165.90.149
Name:   k8s-kubecost-kubecost-2e8ad5d25f-2007371535.ap-northeast-2.elb.amazonaws.com
Address: 3.39.167.45
Name:   k8s-kubecost-kubecost-2e8ad5d25f-2007371535.ap-northeast-2.elb.amazonaws.com
Address: 13.209.120.133
Name:   k8s-kubecost-kubecost-2e8ad5d25f-2007371535.ap-northeast-2.elb.amazonaws.com
Address: 3.36.220.88
```

## 레퍼런스 ##
* https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/cost-monitoring.html
* https://gallery.ecr.aws/kubecost/cost-analyzer

