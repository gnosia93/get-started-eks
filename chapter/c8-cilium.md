<< 아직 테스트 전이다 >>

## 서비스 메시 ##

서비스 메시란 애플리케이션 코드의 수정 없이 eBPF나 사이드카 프록시를 활용해 마이크로서비스 간의 통신(Traffic), 보안(Security), 관찰(Observability)을 인프라 계층에서 통합 관리하는 기술적 메커니즘을 의미한다. 이는 복잡한 서비스 간 연결을 체계적으로 제어하여 개발자가 비즈니스 로직에만 집중할 수 있는 환경을 제공하는 것이 궁극적인 목표이다.
Cilium과 Istio는 모두 서비스 간 통신을 관리하지만, 기술적 기반과 복잡도에서 뚜렷한 차이를 보인다. 
* Cilium: eBPF 기술을 활용해 리눅스 커널 수준에서 트래픽을 처리하므로, 파드마다 프록시를 띄울 필요가 없어 리소스 효율성과 네트워크 성능이 매우 뛰어난 사이드카 없는(Sidecarless) 방식의 차세대 서비스 메시
* Istio: 풍부한 기능과 성숙도를 자랑하는 시장 점유율 1위 솔루션으로, 모든 파드 옆에 Envoy 프록시(사이드카)를 배치해 정교한 L7 트래픽 관리(카나리 배포 등)와 강력한 보안 정책을 제공하는 Full-Option 서비스 메시. 최근 Istio 또한 Ambient Mesh 모드를 통해 사이드카 없는 구조로 진화.

성능과 비용이 최우선이라면 Cilium이 유리하다. eBPF 기반으로 리소스를 적게 쓰기 때문에 노드 사양이 낮거나 트래픽 양이 방대한 대규모 클러스터에서 운영 비용을 크게 절감할 수 있다.
정밀한 트래픽 제어와 성숙도가 중요하다면 Istio 이다. 아주 복잡한 라우팅 규칙(예: 특정 사용자에게만 신규 버전 노출 등)을 적용해야 하거나, 이미 업계에서 검증된 풍부한 레퍼런스가 필요한 경우에 적합하다.

### 서비스 메시 핵심 기능 ###
#### 1. 트래픽 제어 (Traffic Control) ####
  * 로드 밸런싱 (Load Balancing): 라운드 로빈뿐만 아니라 최소 연결(Least Connection) 등 다양한 알고리즘으로 트래픽 분산.
  * 정밀한 라우팅 (Traffic Routing): HTTP 헤더, 쿠키, URL 경로 등을 기준으로 특정 서비스 버전으로 트래픽 유도.
  * 카나리/블루-그린 배포: 신규 버전으로의 트래픽을 % 단위로 서서히 전환.
  * 트래픽 미러링 (Traffic Mirroring): 운영 트래픽을 복사하여 테스트 환경의 신규 버전에 전달 (실제 응답엔 영향 없음).

#### 2. 회복탄력성 (Resiliency) ####
* 서킷 브레이커 (Circuit Breaking): 특정 서비스에 장애가 발생하면 호출을 즉시 차단하여 전체 시스템으로의 장애 전파 방지.
* 재시도 및 타임아웃 (Retries & Timeouts): 통신 실패 시 자동 재시도 횟수와 대기 시간을 인프라 수준에서 설정.
* 결함 주입 (Fault Injection): 테스트를 위해 인위적으로 지연(Latency)이나 에러를 발생시켜 시스템의 견고함 확인.

#### 3. 보안 통신 (Security) ####
* mTLS (Mutual TLS) 암호화: 서비스 간의 모든 통신을 자동으로 암호화하고 상호 인증.
* 인증 및 인가 (AuthN/AuthZ): 어떤 서비스가 어떤 API를 호출할 수 있는지 세밀한 권한 제어.

#### 4. 관찰 가능성 (Observability) ####
* 분산 추적 (Distributed Tracing): 하나의 요청이 여러 서비스를 거치는 전체 경로와 지연 시간 시각화.
* 메트릭 수집: 호출 성공률, 응답 시간, 트래픽 양 등의 데이터를 자동 수집

### 트래픽 흐름 ###

#### 1. Istio (전통적인 사이드카 방식) ####
패킷이 앱에 도달하기까지 커널과 프록시(사용자 공간)를 여러 번 교차하며, 이 과정에서 성능 저하(Context Switch)가 발생한다.
패킷이 커널 ➔ 사이드카 ➔ 커널 ➔ 앱 순으로 복잡하게 이동하며, 네트워크 스택을 두 번씩 타는 오버헤드가 있다.
```
[ 외부 트래픽 ]
      ↓
(커널 계층) ──▶ [ 프록시(사이드카) ] ──┐ (사용자 공간)
      ▲              │               │
      └──────────────┘               ▼
(커널 계층) ◀────────────────── [ 애플리케이션 ] (사용자 공간)
```

#### 2. Cilium (eBPF + 노드당 프록시 방식) ####
대부분의 트래픽은 커널 내에서 최단 거리로 이동하며, 복잡한 검사가 필요한 경우에만 예외적으로 프록시를 방문한다.

* L4
```
[ 외부 트래픽 ]
      ↓
(커널 계층) ──▶ [ eBPF 프로그램 ] ──▶ [ 애플리케이션 ] (사용자 공간)
```
프록시를 아예 거치지 않으며 커널에서 eBPF가 직접 앱으로 쏴주기 때문에 지연 시간이 거의 없다.

* L7
```
[ 외부 트래픽 ]
      ↓
(커널 계층) ──▶ [ eBPF ] ──▶ [ 노드 통합 Envoy ] ──┐
                                     │            │
(커널 계층) ◀────────────────────────┘            ▼
                                       [ 애플리케이션 ] (사용자 공간)
```
PF가 선별한 트래픽만 노드당 하나 있는 Envoy로 보낸다. 사이드카 방식보다 경로가 훨씬 간결하다.


### eBPF는 여기서 어디에 있는가? ###
* veth (Virtual Ethernet) 인터페이스는 양끝이 연결된 '가상 파이프'로 한쪽 끝은 파드 내부에 있고, 다른 쪽 끝은 호스트(노드)의 커널 네트워크 공간에 연결되어 있다.
* Cilium은 이 veth 파이프의 호스트 쪽 입구에 eBPF 프로그램을 삽입한다. 파드에서 데이터가 나오자마자 veth 입구에서 기다리던 eBPF가 패킷을 낚아 챈다.
* 전통적 방식에서는 veth를 나온 패킷이 커널의 복잡한 브릿지(Bridge)나 iptables 룰 수백 개를 줄줄이 통과해야 했고, 여기서 병목이 발생하였다. (AWS VPC-CNI 는 예외)

### VPC CNI 와의 통합 ###
* VPC CNI: 파드가 VPC 내의 실제 보조 IP를 갖기 때문에, 별도의 설정 없이도 파드가 기존 레거시 서버(EC2), RDS(DB), 온프레미스 서버와 직접 통신할 수 있다.
ENI(가상 랜카드)에 파드를 직접 꽂는 방식은 AWS 네트워크 하드웨어의 가속을 100% 활용한다. 또한 AWS Security Group을 파드 단위로 직접 걸 수 있다.
* Cilium 단독: Cilium 고유의 오버레이(VXLAN 등) 네트워크를 쓰게 되면, VPC 인프라 입장에서 파드 IP는 '알 수 없는 대역'이 되어버려 통신을 위한 별도의 게이트웨이나 라우팅 설정이 매우 복잡해 진다. 

#### 통합 전략 ####
VPC CNI는 그대로 두고, 그 위에 Cilium만 얹어서 사용하는 Chaining Mode 로 설정한다.
* VPC CNI: 하위 레이어에서 AWS ENI와 IP 할당을 담당. (빠른 전송)
* Cilium : 상위 레이어에서 eBPF를 통해 보안 정책(L7 필터링), 가시성(Hubble), 서비스 메시 기능을 수행.

## Cilium Chaining Mode 설치 ##

### 1. 설치하기 ###
기존 VPC CNI가 설치된 상태에서 Cilium을 '보조 엔진'으로 얹는 과정이다.
```
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium --version 1.16.0 \
  --namespace kube-system \
  --set cni.chainingMode=aws-eni \
  --set enableIPv4Masquerade=false \
  --set tunnel=disabled \
  --set endpointRoutes.enabled=true \
  --set kubeProxyReplacement=partial \
  --set operator.prometheus.enabled=true \
  --set prometheus.enabled=true  \              # Cilium Agent 자체 지표도 같이 켜는 것을 권장
  --set hubble.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
  --set hubble.ui.enabled=true \
  --set hubble.relay.enabled=true
```
* cni.chainingMode=aws-eni: VPC CNI 뒤에 체인으로 연결함을 명시.
* tunnel=disabled: VPC 내부 통신이므로 별도의 오버레이(VXLAN 등)가 필요 없음

kube-proxy 는 지우지 않고, 그대로 두는 것이 좋다. kubeProxyReplacement=partial 부터 시작한다 (true 로 설정하는 경우 kube-proxy를 아예 사용하지 않는 설정임)이 방식에서는 일부 기능은 eBPF로 처리하고, 나머지는 여전히 iptables(kube-proxy)에 의존하게 된다. 기본적으로 Cilium이 자신 있게 처리할 수 있는 일반적인 서비스 통신만 가로채고, 복잡하거나 클라우드 의존적인 일부 로직은 기존 방식을 유지하게 된다.

#### partial 모드가 처리하는 '일반적 통신' ####
* ClusterIP 서비스: 파드가 서비스 이름(예: my-db)을 호출할 때 일어나는 로드 밸런싱.
* 동작: eBPF가 소켓 레벨(Socket Layer)에서 목적지 IP를 서비스 IP에서 실제 파드 IP로 즉시 바꿔버린다.
* 효과: 이 과정만으로도 동서(East-West) 트래픽의 병목은 대부분 사라진다.

#### partial 모드가 포기(iptables에 위임)하는 것 ####
반면, 아래와 같은 '복잡한 상황'은 partial 모드에서 건드리지 않을 수 있다.
* NodePort / ExternalIPs: 외부에서 노드의 특정 포트로 들어와서 내부 파드로 연결되는 경로입니다.
* HostPort / HostNetwork: 파드가 노드의 네트워크를 직접 공유하거나 특정 포트를 점유하는 경우입니다.
* 복잡한 NAT: 특정 클라우드 환경에서 제공하는 특수한 주소 변환 로직이 섞인 경우입니다.

### 2. 주의사항 ###
* 기존 파드 재시작: Cilium을 설치한 후, 기존에 떠 있던 모든 애플리케이션 파드들을 재시작해야 합니다. 그래야 파드의 네트워크 인터페이스에 Cilium의 eBPF 프로그램이 올바르게 주입(Inject)됩니다.
* MTU 설정: VPC CNI와 Cilium 간의 MTU(Maximum Transmission Unit) 값이 일치해야 합니다. 보통 AWS ENI는 9001(Jumbo Frame)을 사용하므로, Cilium 설정에서도 이를 확인해야 패킷 유실을 막을 수 있습니다.
* kube-proxy 설정: Cilium의 Kube-proxy Replacement 기능을 완벽히 쓰려면 기존 kube-proxy를 삭제해야 하지만, Chaining 모드에서는 호환성을 위해 유지하는 경우가 많습니다. 환경에 따라 kubeProxyReplacement 옵션을 partial 혹은 true로 신중히 결정해야 합니다.
* 보안 그룹(Security Group) 충돌: Cilium의 Network Policy와 AWS의 Security Group이 동시에 적용됩니다. "왜 통신이 안 되지?" 싶을 때 두 곳 모두에서 차단되지 않았는지 확인이 필요합니다. Cilium Hubble을 켜두면 어디서 막혔는지 바로 보입니다.

```
cilium status --wait
```
CNI Chaining: aws-eni 문구가 보인다면 성공

### 3. 허블 ###
```
cilium hubble ui
```


## 레퍼런스 ##
* https://aws.amazon.com/ko/blogs/opensource/getting-started-with-cilium-service-mesh-on-amazon-eks/
