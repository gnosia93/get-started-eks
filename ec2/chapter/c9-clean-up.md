## 리소스 삭제 ##
```
aws ec2 delete-launch-template --launch-template-name asg-lt-arm
aws elbv2 delete-load-balancer --load-balancer-arn $(aws elbv2 describe-load-balancers --names my-alb --query "LoadBalancers[0].LoadBalancerArn" --output text)
TG_ARN=$(aws elbv2 describe-target-groups --names tg-arm --query "TargetGroups[0].TargetGroupArn" --output text | xargs)
aws elbv2 delete-target-group --target-group-arn $TG_ARN
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name asg-arm --force-delete

aws cloudformation delete-stack --stack-name graviton-mig-stack
```
