## ab 부하 생성 ##

```
VSCODE=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:cloudformation:logical-id,Values=BastionHost" \
  --query "Reservations[].Instances[].PublicDnsName" \
  --output text)
echo ${VSCODE}

ssh -i aws-kp-2.pem ec2-user@${VSCODE}
```

apache bench (ab) 를 설치한다
```
sudo dnf update -y
sudo dnf install httpd-tools -y
```

웹 어플리케이션을 테스트 한다.
```
ALB_URL=$(aws cloudformation describe-stacks --stack-name graviton-mig-stack \
  --query "Stacks[0].Outputs[?OutputKey=='ALBURL'].OutputValue" \
  --output text | xargs)
echo "${ALB_URL}"

ab -t 1200 -c 300 -n 1000000 "http://${ALB_URL}/"
```
* -n(총 요청수)을 넉넉히 잡고, -t(시간)를 20분 설정
* -c(동시 접속자)는 서버 사양에 맞게 조정 (예: 50명)

## 밴치마크 대상 ##
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/perf-calro.png)
```
@app.route('/')
def simulate():
    # 몬테카를로 시뮬레이션
    n = 100000
    hits = sum(1 for _ in range(n) if random.random()**2 + random.random()**2 <= 1.0)
    
    result_data = {
        "instance_name": get_metadata("tags/instance/Name"),
        "instance_id": get_metadata("instance-id"),
        "instance_type": get_metadata("instance-type"),
        "private_ip": get_metadata("local-ipv4"),
        "hostname": socket.gethostname(),
        "architecture": platform.machine(),
        "cpu_info": subprocess.getoutput("lscpu | grep 'Model name' | cut -d: -f2").strip(),
        "pi_estimate": 4.0 * hits / n
    }

    # JSON 대신 HTML 템플릿 반환
    return render_template_string(HTML_TEMPLATE, data=result_data)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
```

## Cloudwatch 모니터링 ##
Metrics > All metrics > EC2 하단의 View Automatic Dashboard 링크를 클릭한다.
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/perf-dashboard.png)



### 3가지 핵심 비교 지표 ###

#### 1. 응답 속도 비교 (TargetResponseTime) ####
가장 중요한 지표로, Graviton이 기존 대비 얼마나 빠른지(혹은 느린지) 평균값과 P99(상위 1% 지연 시간)를 확인한다.
* Metric Name: TargetResponseTime
* Dimensions: TargetGroup 별로 필터링하여 비교

#### 2. 처리량 및 에러율 (RequestCount & HTTPCode_Target) ####
Graviton에서 애플리케이션이 안정적으로 동작하는지 확인한다.
* RequestCount: 가중치 설정(예: 8:2)대로 요청이 들어오고 있는지 확인.
* HTTPCode_Target_5XX_Count: Graviton TG에서만 에러가 발생하지 않는지 확인.

#### 3. CPU 사용량 및 비용 효율 (CPUUtilization) ####
인스턴스 자체의 부하를 비교한다.
* Metric Name: CPUUtilization (AWS/EC2 네임스페이스)
* 비교 방법: Graviton은 보통 x86보다 가성비가 좋으므로, 비슷한 응답 속도에서 CPU 사용량이 더 낮은지 확인하는 것이 핵심이다.



