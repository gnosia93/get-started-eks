Kubecost는 쿠버네티스 클러스터 내의 리소스(CPU, 메모리, 스토리지, 네트워크) 소비량을 분석하여 실시간 요금을 추적하고 최적화 방안을 제안하는 도구입니다. AWS EKS와 긴밀하게 통합되어 있어 실무에서 필수로 쓰입니다.

* 실시간 가시성: 어떤 서비스(Pod), 네임스페이스, 레이블이 비용을 많이 쓰는지 시각화합니다.
* AWS 연동: 실제 AWS 빌링 데이터와 연동하여 Spot 인스턴스 할인율이나 예약 인스턴스(RI) 가격을 정확히 반영합니다.
* 비용 절감 제안: "사용되지 않는 노드가 있으니 삭제하라" 또는 "Pod의 리소스 할당량(Request)을 줄이라"는 식의 가이드를 제공합니다.


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

### Kubecost Ingress 설정 ###
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubecost-ingress
  namespace: kubecost
  annotations:
    # ALB 생성 및 인터넷 노출 설정
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          path: /
          pathType: Prefix
          backend:
            service:
              name: kubecost-cost-analyzer
              port:
                number: 9090

```

## 레퍼런스 ##
* https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/cost-monitoring.html
* https://gallery.ecr.aws/kubecost/cost-analyzer

