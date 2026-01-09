
#### 1. GitLab Agent for Kubernetes 활용 (권장) ####
   
이 방식은 클러스터에 에이전트를 설치하여 GitLab과 보안 연결을 유지하며, 별도의 AWS 자격 증명을 노출하지 않고 배포할 수 있는 현대적인 방법입니다. 

준비 단계:
* GitLab 프로젝트 내 .gitlab/agents/<agent-name>/config.yaml 파일을 생성하여 에이전트를 정의합니다.
* GitLab UI의 Infrastructure > Kubernetes clusters 메뉴에서 'Connect a cluster (agent)'를 선택하고 에이전트를 등록합니다.
* 발급된 등록 토큰을 사용해 Helm으로 EKS 클러스터 내에 에이전트를 설치합니다.

배포 방식:
* 파이프라인 .gitlab-ci.yml 파일에서 kubectl 컨텍스트를 해당 에이전트로 설정하면 클러스터에 직접 명령어를 보낼 수 있습니다
