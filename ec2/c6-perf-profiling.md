AWS Graviton(ARM64 아키텍처) 환경에서 Python 코드를 프로파일링할 때는 CPU 아키텍처 특성을 고려한 도구 선택이 중요합니다. 주요 방법은 다음과 같습니다.
1. 전용 분석 도구 활용 (Graviton 최적화)
APerf (AWS Perf): AWS에서 Graviton 프로세서의 성능 분석을 위해 만든 오픈소스 도구입니다. perf, sysstat 등의 데이터를 수집하여 HTML 리포트로 시각화해주며, Graviton 인스턴스에서 uname -m 결과가 aarch64인 경우 바로 설치하여 사용할 수 있습니다.
Arm MAP: Arm Forge에서 제공하는 프로파일러로, Graviton과 같은 ARM 기반 리눅스 환경에서 Python, C++, C 코드를 낮은 오버헤드(5% 미만)로 분석할 수 있습니다. 
2. 샘플링 기반 프로파일러 (운영 환경 추천)
Py-Spy: 코드를 수정하거나 프로그램을 재시작하지 않고도 실행 중인 Python 프로세스에 연결하여 프로파일링할 수 있습니다. Rust로 작성되어 매우 빠르며, ARM64를 지원하여 Graviton 환경에서도 실시간으로 스택 정보를 확인하거나 플레임 그래프(Flame Graph)를 생성하는 데 유용합니다.
사용 예시: py-spy record -o profile.svg --python my_script.py

Amazon CodeGuru Profiler: Lambda나 EC2에서 실행되는 Python 애플리케이션의 성능을 지속적으로 모니터링할 수 있습니다. 현재 Python 3.7~3.9 버전을 지원하며, 시각적인 플레임 그래프와 성능 개선 권장 사항을 제공합니다.
