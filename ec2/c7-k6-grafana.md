## 그라파나 k6 ##
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/k6-grafana.jpg)  

k6 는 Grafana Labs에서 개발한 오픈소스 부하 테스트(Load Testing) 및 성능 테스트 도구로 테스트 시나리오를 자바스크립트로 작성할 수 있고, 다양한 형태의 시나리오 적용이 가능하다. Go 언어로 작성되어 메모리 사용량이 적으면서도 높은 부하(많은 요청)를 발생시킬 수 있으며, 코드로 테스트를 관리할 수 있어 CI/CD 파이프라인에 통합하기 쉽다. k6는 HTTP/1.1, HTTP/2, WebSockets, gRPC 등 다양한 프로토콜을 지원하며, Thresholds 기능을 통해 성능 기준 미달 시 CI/CD 파이프라인을 자동 중단시킬 수 있다. 또한 xk6 익스텐션으로 SQL이나 Kafka까지 기능을 확장할 수 있고, 테스트 결과는 Grafana나 Prometheus와 연동해 실시간으로 시각화할 수 있는 강력한 도구이다.

### [k6 설치](https://grafana.com/docs/k6/latest/set-up/install-k6/?pg=get&plcmt=selfmanaged-box10-cta1) ###

vscode 서버에서 k6 를 설치한다.
```
sudo dnf install -y https://dl.k6.io/rpm/repo.rpm
sudo dnf install -y k6
```

### 리소스 제한값(소프트 리미트) 확인 ###
```
ulimit -Sa
```
[결과]
```
core file size              (blocks, -c) unlimited
data seg size               (kbytes, -d) unlimited
scheduling priority                 (-e) 0
file size                   (blocks, -f) unlimited
pending signals                     (-i) 30446
max locked memory           (kbytes, -l) unlimited
max memory size             (kbytes, -m) unlimited
open files                          (-n) 65535
pipe size                (512 bytes, -p) 8
POSIX message queues         (bytes, -q) 819200
real-time priority                  (-r) 0
stack size                  (kbytes, -s) 10240
cpu time                   (seconds, -t) unlimited
max user processes                  (-u) unlimited
virtual memory              (kbytes, -v) unlimited
file locks                          (-x) unlimited
```
### port 범위 확인 ###
```
sysctl net.ipv4.ip_local_port_range
```
[결과]
```
net.ipv4.ip_local_port_range = 32768    60999
```

## 시나리오 작성 및 테스트 ##

* 성능 선형성 확인: 보통 CPU는 부하가 급증하면 컨텍스트 스위칭 등으로 효율이 떨어진다. 하지만 Graviton3는 코어 간 간섭이 적어 부하를 단계별로(100 -> 400) 올렸을 때 성능이 얼마나 안정적으로 유지되는지(Scalability) 관찰하기 좋다.
* 웜업(Warm-up)의 중요성: k6 공식 문서에 따르면, 갑작스러운 트래픽은 결과 왜곡을 초래할 수 있다. 특히 효율이 좋은 CPU일수록 초기 구동 시의 성능과 안정화 후의 성능 차이를 명확히 구분하는게 필요하다.

```
cat <<EOF > k6-script.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // Graviton3의 높은 코어 효율을 확인하기 위해 단계를 세분화
  stages: [
    { duration: '2m', target: 100 },        // 웜업: VU 100 명까지 증가
    { duration: '6m', target: 400 },        // 부하: 400명 유지 (시뮬레이션 연산 부하 확인)
    { duration: '2m', target: 0 },          // 쿨다운
  ],
  thresholds: {
    // 시뮬레이션 특성상 응답 시간이 길 수 있으므로 p95 기준을 2초로 넉넉히 설정
    'http_req_duration': ['p(95)<2000'],
    'http_req_failed': ['rate<0.01'],
  },
};

export default function () {
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
    },
    timeout: '60s',                         // 연산 시간에 대한 타임 아웃 설정값
  };

  const res = http.get('#BASE_URL#/', params);
  check(res, {
    'is status 200': (r) => r.status === 200,
  });

  sleep(0.5);                               // 가상 유저(VU)의 http 요청 간격 - 요청 보낸 후 0.5초씩 휴식
}
EOF
```
k6-scritp.js 파일의 `#BASE_URL#` 의 값을 테스트 대상 서버로 수정한 후 k6 를 순차적으로 실행한다. 
```
for FILE in X86_INST GRAV_INST; do
    if [ -f "$FILE" ]; then
        export BASE_URL="http://$(cat "$FILE")"
        echo "현재 실행 중: $FILE (BASE_URL: $BASE_URL)"
        
        cat k6-script.js | sed "s|#BASE_URL#|$BASE_URL|g" | k6 run -
    else
        echo "경고: $FILE 파일을 찾을 수 없습니다."
    fi
done
```

* 'http_req_duration': ['p(95)<2000']
 
p95는 "100번의 요청 중 가장 느린 5번 정도를 제외한 나머지 95번은 모두 2초 안에 들어와야 한다"는 뜻으로, 실제 사용자 경험을 훨씬 더 정확하게 반영한다.
몬테카를로 시뮬레이션은 CPU 연산이 많이 들어가기 때문에 일반 웹사이트(보통 500ms 미만)보다 넉넉하게 2000ms로 설정하였다. 

* 'http_req_failed': ['rate<0.01']

에러 발생율(Failure Rate)이 1% 미만이어야 한다는 의미로, 1,000번 요청을 보냈다면 에러가 10개 미만이어야 합격이다. 서버(Nginx+Gunicorn)가 부하를 견디지 못하고 연결을 끊어버리는지 체크하는 장치로, 응답 속도가 아무리 빨라도 10번 중 5번이 서버 에러(500 Internal Server Error)라면 그 시스템은 망가진 것이나 다름없다.


### 테스트 결과 ###
```
현재 실행 중: X86_INST (BASE_URL: http://3.36.133.216)

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: -
        output: -

     scenarios: (100.00%) 1 scenario, 400 max VUs, 10m30s max duration (incl. graceful stop):
              * default: Up to 400 looping VUs for 10m0s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✗ 'p(95)<2000' p(95)=14.55s

    http_req_failed
    ✓ 'rate<0.01' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 15064   25.080851/s
    checks_succeeded...: 100.00% 15064 out of 15064
    checks_failed......: 0.00%   0 out of 15064

    ✓ is status 200

    HTTP
    http_req_duration..............: avg=7.56s min=124.06ms med=7.56s max=17.97s p(90)=13.81s p(95)=14.55s
      { expected_response:true }...: avg=7.56s min=124.06ms med=7.56s max=17.97s p(90)=13.81s p(95)=14.55s
    http_req_failed................: 0.00%  0 out of 15064
    http_reqs......................: 15064  25.080851/s

    EXECUTION
    iteration_duration.............: avg=8.06s min=624.74ms med=8.06s max=18.47s p(90)=14.31s p(95)=15.05s
    iterations.....................: 15064  25.080851/s
    vus............................: 1      min=1          max=400
    vus_max........................: 400    min=400        max=400

    NETWORK
    data_received..................: 35 MB  59 kB/s
    data_sent......................: 1.9 MB 3.1 kB/s




running (10m00.6s), 000/400 VUs, 15064 complete and 0 interrupted iterations
default ✓ [======================================] 000/400 VUs  10m0s
ERRO[0600] thresholds on metrics 'http_req_duration' have been crossed 
현재 실행 중: GRAV_INST (BASE_URL: http://43.202.56.65)

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: -
        output: -

     scenarios: (100.00%) 1 scenario, 400 max VUs, 10m30s max duration (incl. graceful stop):
              * default: Up to 400 looping VUs for 10m0s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✗ 'p(95)<2000' p(95)=14.44s

    http_req_failed
    ✓ 'rate<0.01' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 15156   25.254619/s
    checks_succeeded...: 100.00% 15156 out of 15156
    checks_failed......: 0.00%   0 out of 15156

    ✓ is status 200

    HTTP
    http_req_duration..............: avg=7.52s min=166.44ms med=7.53s max=21.87s p(90)=13.66s p(95)=14.44s
      { expected_response:true }...: avg=7.52s min=166.44ms med=7.53s max=21.87s p(90)=13.66s p(95)=14.44s
    http_req_failed................: 0.00%  0 out of 15156
    http_reqs......................: 15156  25.254619/s

    EXECUTION
    iteration_duration.............: avg=8.02s min=666.98ms med=8.03s max=22.37s p(90)=14.16s p(95)=14.95s
    iterations.....................: 15156  25.254619/s
    vus............................: 2      min=1          max=400
    vus_max........................: 400    min=400        max=400

    NETWORK
    data_received..................: 34 MB  57 kB/s
    data_sent......................: 1.9 MB 3.1 kB/s




running (10m00.1s), 000/400 VUs, 15156 complete and 0 interrupted iterations
default ✓ [======================================] 000/400 VUs  10m0s
ERRO[0600] thresholds on metrics 'http_req_duration' have been crossed 
``` 

### CPU 사용률 비교 ###
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/k6-test-result-1.png)
* X86 : 64 ~ 65%
* Graviton : 54 ~ 55% 
