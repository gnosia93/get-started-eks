## 카나리(Canary) 및 블루-그린(Blue-Green) 구현 ##
ALB의 리스너 규칙에서 하나의 규칙에 두 개의 타겟 그룹을 연결하고 가중치를 부여하면 한다.
* 설정 방법: ALB 리스너 편집 → 규칙(Rule) 수정 → 전달 대상(Forward to)에 타겟그룹 A(기존/Blue)와 타겟그룹 B(신규/Green)를 모두 추가.
* 가중치 조절:
  * 카나리: A: 95% / B: 5%로 설정하여 신규(ARM) 인스턴스로 소량의 트래픽만 흘려보내 성능을 검증.
  * 블루-그린: 검증이 끝나면 A: 0% / B: 100%로 가중치를 변경하여 즉시 전환.

* ALB 리스너 편집 → 규칙(Rule) 수정
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-listener-edit.png)

* 전달 대상(Forward to) 수정
![](https://github.com/gnosia93/get-started-eks/blob/main/ec2/%20images/alb-listener-add-target-group.png)


### AWS CLI 활용 ###

#### 1. 신규 타겟그룹 생성 ####




#### 2. 리스너에 타켓그룹 등록 ####




#### 3. 트래픽 비율조정 ####
