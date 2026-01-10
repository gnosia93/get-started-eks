

```
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium --version 1.16.x \
  --namespace kube-system \
  --set serviceMesh.enabled=true \
  --set kubeProxyReplacement=true \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true
```
* kubeProxyReplacement: kube-proxy를 완전히 대체하여 성능을 극대화합니다. 
* serviceMesh.enabled: L7 트래픽 제어 및 메시 기능 활성화
* hubble: 가시성 확보를 위해 필수적으로 함께 설치하는 것을 추천

```
cilium hubble ui
cilium connectivity test
```

Cilium Service Mesh는 별도의 사이드카 없이 Cilium Ingress Controller나 Gateway API 리소스를 선언하는 것만으로 트래픽 쉐이핑(Canary 배포 등)과 보안 정책을 적용할 수 있습니다. 
현재 기존에 사용 중인 Ingress 컨트롤러(예: ALB Controller, Nginx)가 있나요? 이를 Cilium으로 대체할지, 아니면 함께 혼용할지에 따라 추가 설정이 달라질 수 있습니다


## 레퍼런스 ##
* https://aws.amazon.com/ko/blogs/opensource/getting-started-with-cilium-service-mesh-on-amazon-eks/
