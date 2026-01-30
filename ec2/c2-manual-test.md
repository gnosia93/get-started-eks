## ALB 그라비톤 추가하기  ##
신규로 생성한 ARM 인스턴스를 기존 ALB의 타겟 그룹(Target Group)에 직접 등록하는 방법이다.
AWS 콘솔에서는 ALB의 타겟그룹 선택 → [Targets] 탭 → [Register targets] 클릭 → ARM 인스턴스를 선택 하면 된다.  

여기에서는 AWS CLI 명령어를 이용하여 그라비톤 인스턴스를 하나 만들고 기존 ALB 에 추가해 보도록 한다.  


