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

### 스토리지 볼륨 설정 ###

#### 이슈 ####
아래와 같이 스토리지 볼륨을 사용하는 파드는 Pending 상태에 머물러 있다. StorageClass(SC) 정보를 조회해 보면 Default SC 가 존재하지 않은 것을 확인할 수 있다. 
즉 PersistentVolumeClaim (PVC) 는 있으나 PersistentVolume (PV) 를 만들때 필요한 StorageClass(SC) 가 없는 상태이다.

```
$ kubectl get pvc -n kubecost
NAME                                          STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
aggregator-db-storage-kubecost-aggregator-0   Pending                                                     <unset>                 20m
kubecost-cloud-cost-persistent-configs        Pending                                                     <unset>                 20m
kubecost-finopsagent                          Pending                                                     <unset>                 20m
kubecost-local-store                          Pending                                                     <unset>                 20m
persistent-configs-kubecost-aggregator-0      Pending                                                     <unset>                 20m


$ kubectl get sc
NAME   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2    kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  3d8h

VOLUMEBINDINGMODE
  - 기본값 (Immediate): PVC를 만들자마자 PV가 특정 AZ에 생성된다. 파드가 나중에 다른 AZ에 배치되면 오류가 발생한다.
  - 설정값 (WaitForFirstConsumer): 파드가 스케줄링될 때까지 PV 생성을 지연시키는 방식으로 스케줄러가 파드를 먼저 특정 AZ(예: 2a)에 띄울지 결정하면, 그제서야 EBS를 그 AZ(2a)에 생성된다. 이렇게 하면 첫 배포시 AZ 불일치 문제는 100% 방지되나 가용성에 문제가 발생할 가능성이 있다. 파드 재시작시 PV 바인된 AZ 에서만 재시작 된다. 

$ kubectl describe pvc kubecost-local-store -n kubecost
Name:          kubecost-local-store
Namespace:     kubecost
StorageClass:  
Status:        Pending
Volume:        
Labels:        app=kubecost
               app.kubernetes.io/instance=kubecost
               app.kubernetes.io/managed-by=Helm
               app.kubernetes.io/name=kubecost
               helm.sh/chart=kubecost-3.1.0
Annotations:   helm.sh/resource-policy: keep
               meta.helm.sh/release-name: kubecost
               meta.helm.sh/release-namespace: kubecost
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:      
Access Modes:  
VolumeMode:    Filesystem
Used By:       kubecost-local-store-84c99cddd6-nxmsh
Events:
  Type    Reason         Age                  From                         Message
  ----    ------         ----                 ----                         -------
  Normal  FailedBinding  100s (x82 over 21m)  persistentvolume-controller  no persistent volumes available for this claim and no storage class is set


$ kubectl get pvc kubecost-local-store -n kubecost -o yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    helm.sh/resource-policy: keep
    meta.helm.sh/release-name: kubecost
    meta.helm.sh/release-namespace: kubecost
  creationTimestamp: "2026-01-14T16:23:23Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    app: kubecost
    app.kubernetes.io/instance: kubecost
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: kubecost
    helm.sh/chart: kubecost-3.1.0
  name: kubecost-local-store
  namespace: kubecost
  resourceVersion: "1497096"
  uid: 817b356c-9371-4e39-9fb9-75303c35e1ec
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 32Gi
  volumeMode: Filesystem
status:
  phase: Pending
```

#### 해결 방법 ####
gp3 타입의 디폴트 storage class 를 생성한다. 
```
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true" # 기본값 설정
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```
방금 생성한 gp3 스토리지 클래스가 default 임을 확인한다. 
```
kubectl get sc
```
[결과]
```
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2             kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  3d8h
gp3 (default)   ebs.csi.aws.com         Delete          WaitForFirstConsumer   true                   5s
```

pv 리스트를 확인한다.
```
kubectl get pv -n kubecost
```
[결과]
```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                  STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-3e796b08-c66d-4b7c-8173-2bf11aad429f   1Gi        RWO            Delete           Bound    kubecost/kubecost-cloud-cost-persistent-configs        gp3            <unset>                          6m43s
pvc-44aa47a8-00a4-4fcb-b408-3e077be96ff6   1Gi        RWO            Delete           Bound    kubecost/persistent-configs-kubecost-aggregator-0      gp3            <unset>                          6m43s
pvc-491911fd-3acb-4da5-8f53-6ead0ceb71ad   128Gi      RWO            Delete           Bound    kubecost/aggregator-db-storage-kubecost-aggregator-0   gp3            <unset>                          6m43s
pvc-6af4cf8e-49a3-4cd8-b1d3-e49f26fd8483   8Gi        RWO            Delete           Bound    kubecost/kubecost-finopsagent                          gp3            <unset>                          6m43s
pvc-817b356c-9371-4e39-9fb9-75303c35e1ec   32Gi       RWO            Delete           Bound    kubecost/kubecost-local-store                          gp3            <unset>                          6m45s
```
pvc 리스트를 확인한다.
```
kubectl get pvc -n kubecost
```
[결과]
```
NAME                                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
aggregator-db-storage-kubecost-aggregator-0   Bound    pvc-491911fd-3acb-4da5-8f53-6ead0ceb71ad   128Gi      RWO            gp3            <unset>                 33m
kubecost-cloud-cost-persistent-configs        Bound    pvc-3e796b08-c66d-4b7c-8173-2bf11aad429f   1Gi        RWO            gp3            <unset>                 33m
kubecost-finopsagent                          Bound    pvc-6af4cf8e-49a3-4cd8-b1d3-e49f26fd8483   8Gi        RWO            gp3            <unset>                 33m
kubecost-local-store                          Bound    pvc-817b356c-9371-4e39-9fb9-75303c35e1ec   32Gi       RWO            gp3            <unset>                 33m
persistent-configs-kubecost-aggregator-0      Bound    pvc-44aa47a8-00a4-4fcb-b408-3e077be96ff6   1Gi        RWO            gp3            <unset>                 33m
```

사용자가 원하는 스토리지 요구사항을 PersistentVolumeClaim(PVC)에 담아 요청하면, 쿠버네티스는 미리 정의된 StorageClass(SC)의 설정을 참조하여 실제 물리 디스크인 PersistentVolume(PV)를 자동으로 생성 및 연결(Binding)해주는데, 이를 '동적 할당(Dynamic Provisioning)'이라고 한다.
* StorageClass (SC): 관리자가 스토리지의 종류(EBS gp3 등)와 생성 규칙을 정의해둔 틀.
* PersistentVolume (PV): SC를 통해 실제 인프라(AWS 등)에 생성된 물리적인 '실제 디스크' 자원.
* PersistentVolumeClaim (PVC): 사용자가 필요한 용량과 읽기/쓰기 모드를 명시한 '주문서'이며, 파드(Pod)는 이 주문서를 통해 스토리지와 연결.
* 동적 할당: 사용자가 PVC만 던지면 쿠버네티스가 알아서 SC를 보고 PV를 생성해주므로, 관리자가 매번 수동으로 디스크를 준비할 필요가 없는 '자동화 핵심 기능' 이다.

pvc 를 필요로 하는 Pod 중 kubecost-aggregator-0 조회해 보면, 아래와 같은 claimName 임들을 확인할 수 있다.  
```
kubectl get pod kubecost-aggregator-0 -n kubecost -o yaml | grep -A 10 volumes
```
[결과]
```
  volumes:
  - name: aggregator-db-storage
    persistentVolumeClaim:
      claimName: aggregator-db-storage-kubecost-aggregator-0              # PVC - 클레임명
  - name: persistent-configs
    persistentVolumeClaim:
      claimName: persistent-configs-kubecost-aggregator-0                 # PVC - 클레임명
  - emptyDir:
      sizeLimit: 2Gi
    name: aggregator-staging
  - configMap:
```

#### Kubecost UI ####
![](https://github.com/gnosia93/get-started-eks/blob/main/images/kubecost-dashboard-2.png)


## 레퍼런스 ##
* https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/cost-monitoring.html
* https://gallery.ecr.aws/kubecost/cost-analyzer

