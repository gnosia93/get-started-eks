## OpenCost + KRR로 비용 가시성 & 라이트사이징 ##
전제: EKS 클러스터(앞서 만든 c7g/c6i), Prometheus가 이미 떠 있음(모듈 0의 prometheus-grafana 스택 재활용)

### Step 1. OpenCost 설치 (~10분) ###
```
kubectl create namespace opencost

helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update

# 기존 Prometheus를 가리키도록 설치
helm install opencost opencost/opencost \
  --namespace opencost \
  --set opencost.prometheus.internal.enabled=false \
  --set opencost.prometheus.external.url="http://prometheus-grafana.monitoring.svc:80/prometheus" \
  --set opencost.exporter.defaultClusterId="graviton-workshop"

kubectl -n opencost rollout status deploy/opencost
```

Prometheus URL은 본인 환경에 맞게 바꾸세요. kube-prometheus-stack이면 보통 http://<release>-prometheus.<ns>.svc:9090.

* UI 확인:
```
kubectl -n opencost port-forward svc/opencost 9090:9090
# http://localhost:9090 접속 → 네임스페이스/파드별 비용
```

### Step 2. (선택) CUR 연동으로 실비용 보정 (~15분) ###
추정가 대신 실제 결제가로 보고 싶으면 클라우드 통합을 붙여요. 워크샵 단축하려면 건너뛰고 온디맨드 추정으로 진행해도 됩니다.
```
# cloud-integration.yaml (요지)
athena:
  bucketName: "<cur-athena-결과-버킷>"
  region: "ap-northeast-2"
  database: "athenacurcfn_..."
  table: "..."
  workgroup: "primary"
```
연동하면 RI/Savings Plans/스팟 할인까지 반영된 파드 비용이 나와요. (권한은 IRSA/Pod Identity로 부여)

### Step 3. 비용 베이스라인 추출 (~10분) ###
라이트사이징 전후 비교용으로 현재 비용을 기록해둬요.
```
# OpenCost API로 네임스페이스별 비용 (최근 1일)
curl -s "http://localhost:9090/allocation/compute?window=1d&aggregate=namespace" | jq

# 추론 워크로드 네임스페이스만
curl -s "http://localhost:9090/allocation/compute?window=1d&aggregate=pod&filterNamespaces=llm,embedding" | jq
이 시점 값을 "Before"로 저장.
```

### Step 4. KRR로 라이트사이징 추천 (~15분) ###
```
# KRR 설치 (CLI, 에이전트 없음)
pip install krr
# 또는 brew install krr-cli

# 기존 Prometheus 대상으로 추천 실행
krr simple \
  --prometheus-url "http://localhost:9090/prometheus" \
  -n llm -n embedding \
  --format table
```
출력에서 워크로드별로 이런 걸 봐요.

* 현재 CPU/메모리 request·limit
* 추천 request·limit (실제 사용량 기반)
* 절감 여지(과다 할당분)

#### JSON으로 뽑아 리포트화도 가능: ####
```
krr simple --prometheus-url "http://localhost:9090/prometheus" \
  -n llm -n embedding --format json > krr-recommendations.json
```

### Step 5. 추천값 적용 (~10분) ###
추천대로 워크로드 request/limit을 조정해요. 예: 임베딩 Deployment.
```
kubectl -n embedding patch deploy tei-embedding --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"2"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"4Gi"}
]'
```
실제 값은 KRR이 추천한 수치로 바꾸세요. 추론 워크로드는 처리량에 민감하니, 추천값 적용 후 부하테스트로 지연/처리량이 안 깨지는지 꼭 확인.

### Step 6. 절감 효과 확인 (~15분) ###
조정 후 충분히(예: 30분~1시간) 돌린 뒤 다시 비용을 뽑아 Before와 비교.
```
curl -s "http://localhost:9090/allocation/compute?window=1h&aggregate=pod&filterNamespaces=llm,embedding" | jq
```
비교 표 예시:
```
워크로드	Before request	After request	파드 비용 변화
임베딩(TEI)	CPU 4 / 8Gi	CPU 2 / 4Gi	-약 X%
소형 LLM	...	...	...
```
라이트사이징으로 노드에 더 많은 파드가 들어가면(밀도↑) 노드 수가 줄어 추가 절감이 생겨요.

* 아키텍처 절감: x86 → Graviton (모듈 4 벤치마크)
* 리소스 절감: 과다 할당 → KRR 라이트사이징 (이 핸즈온)
* "Graviton으로 옮기고(가성비) + 적정 크기로 조이면(낭비 제거) 비용이 두 번 줄어든다"가 핵심 결론입니다.

### 실습 시 주의 ###
* KRR 추천은 과거 사용량 기반이라, 부하 패턴이 충분히 쌓인 뒤(최소 몇 시간~며칠) 추천이 의미 있어요. 워크샵에선 부하 생성기로 트래픽을 미리 돌려두세요.
* 추론 워크로드는 request를 너무 조이면 지연이 튀어요. 적용 후 반드시 부하테스트로 검증.
* OpenCost 추정가는 온디맨드 기준. 정확한 비교가 목적이면 Step 2(CUR 연동) 권장.
