
### 1. APerf (AWS Perf) ###
AWS에서 Graviton 프로세서의 성능 분석을 위해 만든 오픈소스 도구로 perf, sysstat 등의 데이터를 수집하여 HTML 리포트로 시각화해 준다.

### 2. Py-Spy ###
Py-Spy 는 코드를 수정하거나 프로그램을 재시작하지 않고도 실행 중인 Python 프로세스에 연결하여 프로파일링할 수 있다. Rust로 작성되어 매우 빠르며, ARM64를 지원하여 Graviton 환경에서도 실시간으로 스택 정보를 확인하거나 플레임 그래프(Flame Graph)를 생성하는 데 유용하다.
```
py-spy record -o profile.svg --python my_script.py
```
### 3. async-profiler ###
async-profiler는 JVM(Java Virtual Machine) 환경에서 성능 병목 지점을 찾기 위해 설계된 가장 정교한 오픈소스 프로파일러 중 하나이다.

### 4. Amazon CodeGuru Profiler ### 
Lambda나 EC2에서 실행되는 Python 애플리케이션의 성능을 지속적으로 모니터링할 수 있다. 현재 Python 3.7~3.9 버전을 지원하며, 시각적인 플레임 그래프와 성능 개선 권장 사항을 제공한다.
