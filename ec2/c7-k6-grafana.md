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
테스트 대상 서버의 http 주소를 BASE_URL 에 입력하여 export 한 후, k6-scritp.js 파일을 생성한다. 
```
export BASE_URL=http://ec2-13-124-236-120.ap-northeast-2.compute.amazonaws.com 
```
```
cat <<EOF > k6-script.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // Graviton3의 높은 코어 효율을 확인하기 위해 단계를 세분화
  stages: [
    { duration: '1m', target: 50 },        // 웜업: VU 50명까지 증가
    { duration: '3m', target: 200 },       // 부하: 200명 유지 (시뮬레이션 연산 부하 확인)
    { duration: '1m', target: 0 },         // 쿨다운
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

  const res = http.get('${BASE_URL}/', params);
  check(res, {
    'is status 200': (r) => r.status === 200,
  });

  sleep(0.5);                               // 가상 유저(VU)의 http 요청 간격 - 요청 보낸 후 0.5초씩 휴식
}
EOF
```
* 'http_req_duration': ['p(95)<2000']
 
p95는 "100번의 요청 중 가장 느린 5번 정도를 제외한 나머지 95번은 모두 2초 안에 들어와야 한다"는 뜻으로, 실제 사용자 경험을 훨씬 더 정확하게 반영한다.
몬테카를로 시뮬레이션은 CPU 연산이 많이 들어가기 때문에 일반 웹사이트(보통 500ms 미만)보다 넉넉하게 2000ms로 설정하였다. 

* 'http_req_failed': ['rate<0.01']

에러 발생율(Failure Rate)이 1% 미만이어야 한다는 의미로, 1,000번 요청을 보냈다면 에러가 10개 미만이어야 합격이다. 서버(Nginx+Gunicorn)가 부하를 견디지 못하고 연결을 끊어버리는지 체크하는 장치로, 응답 속도가 아무리 빨라도 10번 중 5번이 서버 에러(500 Internal Server Error)라면 그 시스템은 망가진 것이나 다름없다.

```
k6 run k6-script.js
```
[결과]
* graviton 
```
k6 run k6-script.js

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: k6-script.js
        output: -

     scenarios: (100.00%) 1 scenario, 200 max VUs, 5m30s max duration (incl. graceful stop):
              * default: Up to 200 looping VUs for 5m0s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✗ 'p(95)<2000' p(95)=7.04s

    http_req_failed
    ✓ 'rate<0.01' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 7392    24.599971/s
    checks_succeeded...: 100.00% 7392 out of 7392
    checks_failed......: 0.00%   0 out of 7392

    ✓ is status 200

    HTTP
    http_req_duration..............: avg=3.6s min=163.34ms med=3.58s max=8.59s p(90)=6.63s p(95)=7.04s
      { expected_response:true }...: avg=3.6s min=163.34ms med=3.58s max=8.59s p(90)=6.63s p(95)=7.04s
    http_req_failed................: 0.00%  0 out of 7392
    http_reqs......................: 7392   24.599971/s

    EXECUTION
    iteration_duration.............: avg=4.1s min=663.86ms med=4.08s max=9.09s p(90)=7.13s p(95)=7.54s
    iterations.....................: 7392   24.599971/s
    vus............................: 3      min=1         max=200
    vus_max........................: 200    min=200       max=200

    NETWORK
    data_received..................: 20 MB  66 kB/s
    data_sent......................: 1.2 MB 4.1 kB/s




running (5m00.5s), 000/200 VUs, 7392 complete and 0 interrupted iterations
default ✓ [======================================] 000/200 VUs  5m0s
ERRO[0300] thresholds on metrics 'http_req_duration' have been crossed 
```

* 86
```
         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: k6-script.js
        output: -

     scenarios: (100.00%) 1 scenario, 200 max VUs, 5m30s max duration (incl. graceful stop):
              * default: Up to 200 looping VUs for 5m0s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✗ 'p(95)<2000' p(95)=7.05s

    http_req_failed
    ✓ 'rate<0.01' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 7358    24.493507/s
    checks_succeeded...: 100.00% 7358 out of 7358
    checks_failed......: 0.00%   0 out of 7358

    ✓ is status 200

    HTTP
    http_req_duration..............: avg=3.63s min=131.39ms med=3.62s max=8.99s p(90)=6.71s p(95)=7.05s
      { expected_response:true }...: avg=3.63s min=131.39ms med=3.62s max=8.99s p(90)=6.71s p(95)=7.05s
    http_req_failed................: 0.00%  0 out of 7358
    http_reqs......................: 7358   24.493507/s

    EXECUTION
    iteration_duration.............: avg=4.13s min=631.76ms med=4.12s max=9.49s p(90)=7.21s p(95)=7.55s
    iterations.....................: 7358   24.493507/s
    vus............................: 2      min=1         max=200
    vus_max........................: 200    min=200       max=200

    NETWORK
    data_received..................: 17 MB  57 kB/s
    data_sent......................: 1.2 MB 4.0 kB/s




running (5m00.4s), 000/200 VUs, 7358 complete and 0 interrupted iterations
default ✓ [======================================] 000/200 VUs  5m0s
ERRO[0300] thresholds on metrics 'http_req_duration' have been crossed 
``` 

### CPU 사용률 비교 ###
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/k6-test-result.png)
