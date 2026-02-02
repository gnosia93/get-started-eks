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

## 테스트 작성 및 실행 ##
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

export default function () {
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
    },
    timeout: '60s',         // 연산 시간이 길어질 것에 대비해 타임아웃 확장
  };

  const res = http.get('${BASE_URL}/', params);

  check(res, {
    'is status 200': (r) => r.status === 200,
  });
  sleep(0.5);   // 가상 유저(VU) 각각이 개별적으로 0.5초씩 휴식
}
EOF
```
* 'http_req_duration': ['p(95)<2000'],
  * 단순 평균값(Average)은 아주 빠른 응답과 아주 느린 응답이 섞이면 왜곡.
  * p95는 "100번의 요청 중 가장 느린 5번 정도를 제외한 나머지 95번은 모두 2초 안에 들어와야 한다"는 뜻으로, 실제 사용자 경험을 훨씬 더 정확하게 반영.
  * 몬테카를로 시뮬레이션은 CPU 연산이 많이 들어가기 때문에 일반 웹사이트(보통 500ms 미만)보다 넉넉하게 2000ms로 설정.
* 'http_req_failed': ['rate<0.01']
  * 에러 발생율(Failure Rate)이 1% 미만이어야 한다는 뜻.
  * 0.01은 1%를 의미로 1,000번 요청을 보냈다면 에러가 10개 미만이어야 합격.
  * 응답 속도가 아무리 빨라도 10번 중 5번이 서버 에러(500 Internal Server Error)라면 그 시스템은 망가진 것이나 다름없다. 서버(Nginx+Gunicorn)가 부하를 견디지 못하고 연결을 끊어버리는지 체크하는 장치이다.

```
k6 run k6-script.js
```
