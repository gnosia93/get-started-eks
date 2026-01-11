## 서비스 메시 ##

서비스 메시란 애플리케이션 코드의 수정 없이 eBPF나 사이드카 프록시를 활용해 마이크로서비스 간의 통신(Traffic), 보안(Security), 관찰(Observability)을 인프라 계층에서 통합 관리하는 기술적 메커니즘을 의미한다. 이는 복잡한 서비스 간 연결을 체계적으로 제어하여 개발자가 비즈니스 로직에만 집중할 수 있는 환경을 제공하는 것이 궁극적인 목표이다.
Cilium과 Istio는 모두 서비스 간 통신을 관리하지만, 기술적 기반과 복잡도에서 뚜렷한 차이를 보인다. 
* Cilium: eBPF 기술을 활용해 리눅스 커널 수준에서 트래픽을 처리하므로, 파드마다 프록시를 띄울 필요가 없어 리소스 효율성과 네트워크 성능이 매우 뛰어난 사이드카 없는(Sidecarless) 방식의 차세대 서비스 메시
* Istio: 풍부한 기능과 성숙도를 자랑하는 시장 점유율 1위 솔루션으로, 모든 파드 옆에 Envoy 프록시(사이드카)를 배치해 정교한 L7 트래픽 관리(카나리 배포 등)와 강력한 보안 정책을 제공하는 Full-Option 서비스 메시. 최근 Istio 또한 Ambient Mesh 모드를 통해 사이드카 없는 구조로 진화.

성능과 비용이 최우선이라면 Cilium이 유리하다. eBPF 기반으로 리소스를 적게 쓰기 때문에 노드 사양이 낮거나 트래픽 양이 방대한 대규모 클러스터에서 운영 비용을 크게 절감할 수 있다.
정밀한 트래픽 제어와 성숙도가 중요하다면 Istio 이다. 아주 복잡한 라우팅 규칙(예: 특정 사용자에게만 신규 버전 노출 등)을 적용해야 하거나, 이미 업계에서 검증된 풍부한 레퍼런스가 필요한 경우에 적합하다.

### 서비스 메시 핵심 기능 ###
1. 트래픽 제어 (Traffic Control)
  * 로드 밸런싱 (Load Balancing): 라운드 로빈뿐만 아니라 최소 연결(Least Connection) 등 다양한 알고리즘으로 트래픽 분산.
  * 정밀한 라우팅 (Traffic Routing): HTTP 헤더, 쿠키, URL 경로 등을 기준으로 특정 서비스 버전으로 트래픽 유도.
  * 카나리/블루-그린 배포: 신규 버전으로의 트래픽을 % 단위로 서서히 전환.
  * 트래픽 미러링 (Traffic Mirroring): 운영 트래픽을 복사하여 테스트 환경의 신규 버전에 전달 (실제 응답엔 영향 없음).

2. 회복탄력성 (Resiliency)
* 서킷 브레이커 (Circuit Breaking): 특정 서비스에 장애가 발생하면 호출을 즉시 차단하여 전체 시스템으로의 장애 전파 방지.
* 재시도 및 타임아웃 (Retries & Timeouts): 통신 실패 시 자동 재시도 횟수와 대기 시간을 인프라 수준에서 설정.
* 결함 주입 (Fault Injection): 테스트를 위해 인위적으로 지연(Latency)이나 에러를 발생시켜 시스템의 견고함 확인.

3. 보안 통신 (Security)
* mTLS (Mutual TLS) 암호화: 서비스 간의 모든 통신을 자동으로 암호화하고 상호 인증.
* 인증 및 인가 (AuthN/AuthZ): 어떤 서비스가 어떤 API를 호출할 수 있는지 세밀한 권한 제어.

4. 관찰 가능성 (Observability)
* 분산 추적 (Distributed Tracing): 하나의 요청이 여러 서비스를 거치는 전체 경로와 지연 시간 시각화.
* 메트릭 수집: 호출 성공률, 응답 시간, 트래픽 양 등의 데이터를 자동 수집

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
