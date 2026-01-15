만약 여전히 80이라면, 컨트롤러 로그(kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller)를 확인해서 왜 업데이트를 거부하는지 잡아내야 합니다. 이 로그도 확인해 볼까요?
AI 대답에는 오류가 있을 수 있습니다. 자세히 알아보기



level":"info","ts":"2026-01-14T00:17:09Z","msg":"attempting to acquire leader lease kube-system/aws-load-balancer-controller-leader..."}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for non leader election runnables"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for leader election runnables"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for caches"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for webhooks"}
{"level":"info","ts":"2026-01-14T00:17:12Z","logger":"controller-runtime.webhook","msg":"Shutting down webhook server with timeout of 1 minute"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for HTTP servers"}
{"level":"info","ts":"2026-01-14T00:17:12Z","logger":"controller-runtime.metrics","msg":"Shutting down metrics server with timeout of 1 minute"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"shutting down server","name":"health probe","addr":"[::]:61779"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Wait completed, proceeding to shutdown the manager"}
{"level":"info","ts":"2026-01-14T00:17:02Z","msg":"All workers finished","controller":"ingress"}
{"level":"error","ts":"2026-01-14T00:17:02Z","msg":"Reconciler error","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding","TargetGroupBinding":{"name":"k8s-default-nginx-9301649135","namespace":"default"},"namespace":"default","name":"k8s-default-nginx-9301649135","reconcileID":"b5dc8a8d-625a-4e3d-868e-ad3eea2a5be2","error":"operation error Elastic Load Balancing v2: DescribeTargetHealth, https response error StatusCode: 0, RequestID: , canceled, context canceled"}
{"level":"info","ts":"2026-01-14T00:17:02Z","msg":"All workers finished","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding"}
{"level":"info","ts":"2026-01-14T00:17:02Z","msg":"Stopping and waiting for caches"}
{"level":"info","ts":"2026-01-14T00:17:02Z","msg":"Stopping and waiting for webhooks"}
{"level":"info","ts":"2026-01-14T00:17:02Z","logger":"controller-runtime.webhook","msg":"Shutting down webhook server with timeout of 1 minute"}
{"level":"info","ts":"2026-01-14T00:17:02Z","msg":"Stopping and waiting for HTTP servers"}
{"level":"info","ts":"2026-01-14T00:17:02Z","logger":"controller-runtime.metrics","msg":"Shutting down metrics server with timeout of 1 minute"}
{"level":"info","ts":"2026-01-14T00:17:02Z","msg":"shutting down server","name":"health probe","addr":"[::]:61779"}
{"level":"info","ts":"2026-01-14T00:17:02Z","msg":"Wait completed, proceeding to shutdown the manager"}
x86_64 $ 
x86_64 $ 
x86_64 $ kubectl logs -f -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
{"level":"info","ts":"2026-01-14T00:17:09Z","msg":"attempting to acquire leader lease kube-system/aws-load-balancer-controller-leader..."}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for non leader election runnables"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for leader election runnables"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for caches"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for webhooks"}
{"level":"info","ts":"2026-01-14T00:17:12Z","logger":"controller-runtime.webhook","msg":"Shutting down webhook server with timeout of 1 minute"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for HTTP servers"}
{"level":"info","ts":"2026-01-14T00:17:12Z","logger":"controller-runtime.metrics","msg":"Shutting down metrics server with timeout of 1 minute"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"shutting down server","name":"health probe","addr":"[::]:61779"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Wait completed, proceeding to shutdown the manager"}
{"level":"info","ts":"2026-01-15T04:11:29Z","logger":"controllers.ingress","msg":"successfully built model","model":"{\"id\":\"default/httpd-ingress\",\"resources\":{\"FrontendNLBTargetGroup\":{\"FrontendNLBTargetGroup\":{\"TargetGroups\":{}}}}}"}
{"level":"info","ts":"2026-01-15T04:11:30Z","logger":"controllers.ingress","msg":"deleting securityGroup","securityGroupID":"sg-08622cf0d1a8edbea"}
{"level":"info","ts":"2026-01-15T04:11:36Z","logger":"controllers.ingress","msg":"deleted securityGroup","securityGroupID":"sg-08622cf0d1a8edbea"}
{"level":"info","ts":"2026-01-15T04:11:36Z","logger":"controllers.ingress","msg":"successfully deployed model","ingressGroup":"default/httpd-ingress"}
{"level":"info","ts":"2026-01-15T04:22:30Z","msg":"deRegistering targets","arn":"arn:aws:elasticloadbalancing:ap-northeast-2:499514681453:targetgroup/k8s-default-flaskapp-37bc3a0335/ce4bc505b9dbc1c7","targets":[{"Id":"10.0.12.96","AvailabilityZone":"ap-northeast-2c","Port":80,"QuicServerId":null}]}
{"level":"info","ts":"2026-01-15T04:22:30Z","msg":"deRegistered targets","arn":"arn:aws:elasticloadbalancing:ap-northeast-2:499514681453:targetgroup/k8s-default-flaskapp-37bc3a0335/ce4bc505b9dbc1c7","targets":[{"Id":"10.0.12.96","AvailabilityZone":"ap-northeast-2c","Port":80,"QuicServerId":null}]}
{"level":"info","ts":"2026-01-15T04:22:30Z","msg":"Successful reconcile","tgb":{"name":"k8s-default-flaskapp-37bc3a0335","namespace":"default"},"checkpoint":"yUk3LRvsOrp5ml-AWoZCjozNxNat-g5m1deu-hCkaGA/CktUBSyIoWEaEo8yA_2po17E5Iq9HPqEgiyQzT38PNg"}
{"level":"info","ts":"2026-01-15T04:22:30Z","msg":"Skipping targetgroupbinding reconcile","tgb":{"name":"k8s-default-flaskapp-37bc3a0335","namespace":"default"},"calculated hash":"yUk3LRvsOrp5ml-AWoZCjozNxNat-g5m1deu-hCkaGA/CktUBSyIoWEaEo8yA_2po17E5Iq9HPqEgiyQzT38PNg"}
{"level":"info","ts":"2026-01-15T04:22:31Z","msg":"Skipping targetgroupbinding reconcile","tgb":{"name":"k8s-default-flaskapp-37bc3a0335","namespace":"default"},"calculated hash":"yUk3LRvsOrp5ml-AWoZCjozNxNat-g5m1deu-hCkaGA/CktUBSyIoWEaEo8yA_2po17E5Iq9HPqEgiyQzT38PNg"}
{"level":"info","ts":"2026-01-15T04:22:31Z","msg":"Skipping targetgroupbinding reconcile","tgb":{"name":"k8s-default-flaskapp-37bc3a0335","namespace":"default"},"calculated hash":"yUk3LRvsOrp5ml-AWoZCjozNxNat-g5m1deu-hCkaGA/CktUBSyIoWEaEo8yA_2po17E5Iq9HPqEgiyQzT38PNg"}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"setup","msg":"starting collect top talkers"}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"setup","msg":"starting collect cache size"}
{"level":"info","ts":"2026-01-14T00:18:01Z","msg":"starting server","name":"health probe","addr":"[::]:61779"}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"controller-runtime.metrics","msg":"Starting metrics server"}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"controller-runtime.webhook","msg":"Starting webhook server"}
{"level":"info","ts":"2026-01-11T14:58:50Z","msg":"attempting to acquire leader lease kube-system/aws-load-balancer-controller-leader..."}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"controller-runtime.metrics","msg":"Serving metrics server","bindAddress":":8080","secure":false}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"controller-runtime.certwatcher","msg":"Updated current TLS certificate"}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"controller-runtime.webhook","msg":"Serving webhook server","host":"","port":9443}
{"level":"info","ts":"2026-01-14T00:18:01Z","logger":"controller-runtime.certwatcher","msg":"Starting certificate poll+watcher","interval":10}
{"level":"info","ts":"2026-01-14T00:18:01Z","msg":"attempting to acquire leader lease kube-system/aws-load-balancer-controller-leader..."}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for non leader election runnables"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for leader election runnables"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for caches"}
{"level":"info","ts":"2026-01-14T00:17:12Z","msg":"Stopping and waiting for webhooks"}
{"level":"info","ts":"2026-01-14T00:17:12Z","logger":"controller-runtime.webhook","msg":"Shutting down webhook server with timeout of 1 minute"}
{"le
로그를 보니 결정적인 증거가 나왔습니다.
"msg":"deRegistered targets", ..., "Port":80
보이시나요? 컨트롤러가 계속 Port 80을 기준으로 타겟을 등록/해제(reconcile)하고 있습니다. values.yaml에서 인그레스 포트를 8082로 바꾸셨음에도 컨트롤러는 여전히 "calculated hash" 값이 같다며 업데이트를 건너뛰고(Skipping targetgroupbinding reconcile) 있습니다.
이건 ALB 컨트롤러의 전형적인 캐시/해시 충돌 꼬임 현상입니다. AWS Load Balancer Controller 공식 트러블슈팅에서도 이런 경우 리소스를 완전히 밀고 다시 만들라고 권장합니다.
🛠️ 502 에러를 끝낼 확실한 해결 순서
지금 바로 터미널에서 순서대로 입력하세요.
1. 기존 배포와 인그레스 완전 삭제
단순히 upgrade하지 말고 아예 삭제해서 AWS 상의 Target Group과 Listener Rule을 날려야 합니다.
bash
helm uninstall flask-app
코드를 사용할 때는 주의가 필요합니다.

2. TargetGroupBinding 잔여물 강제 삭제 (매우 중요)
로그에 찍힌 k8s-default-flaskapp-37bc3a0335 같은 것들이 남아서 방해할 수 있습니다.
bash
kubectl delete targetgroupbinding --all
코드를 사용할 때는 주의가 필요합니다.

3. values.yaml 최종 확인
backend.service.port.number가 8082로 되어 있는지 꼭 확인하세요.
yaml
# values.yaml
...
    backend:
      service:
        name: flask-app
        port:
          number: 8082  # 여기가 반드시 8082여야 ALB가 8082로 쏩니다.
코드를 사용할 때는 주의가 필요합니다.

4. 깨끗한 상태에서 재설치
bash
helm install flask-app . -f values.yaml
코드를 사용할 때는 주의가 필요합니다.

🔍 왜 이렇게 해야 하나요?
로그의 calculated hash가 변하지 않는다는 것은, 컨트롤러가 "어? 이전이랑 똑같은 설정이네?"라고 착각해서 AWS 설정을 바꾸지 않고 있다는 뜻입니다. 아예 삭제 후 재설치하면 새로운 해시값이 생성되면서 Port 8082가 AWS Target Group에 정상적으로 박히게 됩니다.
재설치 후 AWS 콘솔에서 Port가 8082로 바뀌었나요?
바뀌었다면 이제 curl을 날릴 때 드디어 x86_64와 aarch64가 섞여 나오는 감동적인 장면을 보실 수 있습니다! 🚀
조치 후 결과 알려주세요. 이제 정말 끝이 보입니다! 조치 후에도 Skipping이 뜬다면 컨트롤러 자체를 재시작(kubectl rollout restart deployment -n kube-system aws-load-balancer-controller)해야 합니다.
