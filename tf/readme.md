
___테라폼으로 VPC를 빌드하는데 대략 3분 정도의 시간이 소요된다.___

### VPC 아키텍처 ###
![](https://github.com/gnosia93/get-started-eks/blob/main/images/vpc-arch-2.png)
* VPC / NAT GW
* Subnets (Public / Private)
* Graviton EC2 for Code-Server
* X86 EC2 for Code-Server
* Security Groups
* S3 bucket 

### [테라폼 설치](https://developer.hashicorp.com/terraform/install) ###
mac 의 경우 아래의 명령어로 설치할 수 있다. 
```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### VPC 생성 ###
테라폼으로 VPC 및 접속용 vs-code EC2 인스턴스를 생성한다.   
```
git pull https://github.com/gnosia93/get-started-eks.git
cd training-on-eks/tf
terraform init
```
[결과]
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/http...
- Installing hashicorp/aws v6.27.0...
- Installed hashicorp/aws v6.27.0 (signed by HashiCorp)
- Installing hashicorp/http v3.5.0...
- Installed hashicorp/http v3.5.0 (signed by HashiCorp)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
VPC 를 생성한다. 
```
terraform apply -auto-approve
```

### VPC 확인 ###
```
terraform output
```

### VPC 삭제 ###
워크샵과 관련된 리소스를 모두 삭제한다.
```
terraform destroy --auto-approve
```


## 레퍼런스 ##

* [Install the Linux package on Amazon Linux 2023](https://docs.gitlab.com/install/package/amazonlinux_2023/)
* [gitlab 설치](https://blog.false.kr/posts/Computing/OS/Linux/Rocky/Rocky-Gitlab-CE-Install.html#gitlab-%E1%84%89%E1%85%A5%E1%86%AF%E1%84%8E%E1%85%B5) 
* [Modernize your applications with App2Container](https://workshops.aws/categories/Containers?tag=app2container)
* [Accelerate modernization of your application using App2Container](https://aws.amazon.com/ko/blogs/containers/accelerate-modernization-of-your-application-using-app2container-containerizing-it-and-deploying-to-ecs-fargate/)
* [Amazon Q Developer Transform](https://aws.amazon.com/ko/q/developer/transform/)
