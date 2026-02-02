### [k6 설치](https://grafana.com/docs/k6/latest/set-up/install-k6/?pg=get&plcmt=selfmanaged-box10-cta1) 및 설정 ###
vscode 서버에서 k6 를 설치한다.
```
sudo dnf install -y https://dl.k6.io/rpm/repo.rpm
sudo dnf install -y k6
```

#### 리소스 제한값(소프트 리미트) 확인 ####
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
#### port 범위 확인 ####
```
sysctl net.ipv4.ip_local_port_range
```
[결과]
```
net.ipv4.ip_local_port_range = 32768    60999
```

## 테스트 코드 작성 및 실행 ##
[script.js]
```
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // Graviton3의 높은 코어 효율을 확인하기 위해 단계를 세분화
  stages: [
    { duration: '1m', target: 50 },  // 웜업: VU 50명까지 증가
    { duration: '3m', target: 200 }, // 부하: 200명 유지 (시뮬레이션 연산 부하 확인)
    { duration: '1m', target: 0 },   // 쿨다운
  ],
  thresholds: {
    // 시뮬레이션 특성상 응답 시간이 길 수 있으므로 p95 기준을 2초로 넉넉히 설정
    'http_req_duration': ['p(95)<2000'],
    'http_req_failed': ['rate<0.01'],
  },
};

// 테스트 환경에 맞는 URL 설정
const BASE_URL = 'http://your-graviton-server-ip';

export default function () {
  // 몬테카를로 시뮬레이션에 필요한 파라미터 (예: 반복 횟수)
  const payload = JSON.stringify({
    iterations: 10000,
    seed: Math.floor(Math.random() * 1000000),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      // Gunicorn/Nginx 성능 측정을 위해 Keep-Alive 유지
      'Connection': 'keep-alive',
    },
    timeout: '60s', // 연산 시간이 길어질 것에 대비해 타임아웃 확장
  };

  const res = http.post(`${BASE_URL}/simulate`, payload, params);

  check(res, {
    'is status 200': (r) => r.status === 200,
    'has calculation result': (r) => r.json().hasOwnProperty('result'),
  });

  // Gunicorn 워커가 다음 요청을 받을 준비 시간을 고려해 짧은 휴식
  sleep(0.5);
}
```
```
k6 run script.js
```
