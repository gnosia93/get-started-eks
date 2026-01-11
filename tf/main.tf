provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ------------------------------------------------
# VPC 및 네트워크 구성
# ------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.cluster_name
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.available.names)
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  tags = { 
      Name = "GSE-pub-subnet-${count.index + 1}"
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "private" {
  count             = length(data.aws_availability_zones.available.names)
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main.id
  tags = { 
    Name = "GSE-priv-subnet-${count.index + 1}"
    "karpenter.sh/discovery" = var.cluster_name
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_eip" "nat" {
  domain           = "vpc"
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


# ------------------------------------------------
# EC2 인스턴스용 IAM Role 및 Profile 추가 <--- 이 부분이 추가되었습니다.
# ------------------------------------------------

resource "aws_iam_role" "eks_creator_role" {
  name = "GetStartedEKS_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# EKS 클러스터 생성을 위한 필수 권한 부여
# Note: 이 정책들은 클러스터 생성에 필요한 거의 모든 권한을 포함하므로 주의해야 합니다.
resource "aws_iam_role_policy_attachment" "eks_creator_policy_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.eks_creator_role.name
}

# EC2 인스턴스에 IAM Role을 연결하기 위한 Instance Profile
resource "aws_iam_instance_profile" "eks_creator_profile" {
  name = "GetStartedEKS_Profile"
  role = aws_iam_role.eks_creator_role.name
}



# ------------------------------------------------
# Graviton / X86 EC2 인스턴스 구성
# ------------------------------------------------

data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-arm64"]
  }
}

data "aws_ami" "al2023_x86_64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}


resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id
  name   = "eks-host-sg"

  # SSH 접속 허용
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IPv4 주소 허용
  }

  # VS Code Server (Code Server) 접속 허용
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = local.allowed_ip_cidrs
  }

  # Gitlab KAS 접속 허용.
  ingress {
    from_port   = 8150
    to_port     = 8150
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] 
  }

  # VS Code Server (Code Server) 접속 허용
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = concat(local.allowed_ip_cidrs, [aws_vpc.main.cidr_block])
  }

  # Gitlab Server (eks 의 runner pod 통신)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.allowed_ip_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "graviton_box" {
  ami                         = data.aws_ami.al2023_arm64.id
  instance_type               = var.graviton_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  # IAM Instance Profile 연결 <--- EC2에 권한을 부여합니다.
  iam_instance_profile = aws_iam_instance_profile.eks_creator_profile.name

  // 루트 볼륨 크기를 30GB로 설정
  root_block_device {
    volume_size = 30 # GiB 단위
    volume_type = "gp3" # 최신 gp3 볼륨 타입 사용
  }

  user_data = <<_DATA
#!/bin/bash
sudo -u ec2-user -i <<'EC2_USER_SCRIPT'
curl -fsSL https://code-server.dev/install.sh | sh && sudo systemctl enable --now code-server@ec2-user
sleep 5
sed -i 's/127.0.0.1:8080/0.0.0.0:9090/g; s/auth: password/auth: none/g' /home/ec2-user/.config/code-server/config.yaml
EC2_USER_SCRIPT

echo 'export PS1="$(uname -m) \$ "' >> /home/ec2-user/.bashrc
sudo systemctl restart code-server@ec2-user
_DATA

  tags = {
    Name = "code-server-graviton"
  }
}

resource "aws_instance" "x86_box" {
  ami                         = data.aws_ami.al2023_x86_64.id
  instance_type               = var.x86_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  # IAM Instance Profile 연결 <--- EC2에 권한을 부여합니다.
  iam_instance_profile = aws_iam_instance_profile.eks_creator_profile.name

  // 루트 볼륨 크기를 30GB로 설정
  root_block_device {
    volume_size = 30 # GiB 단위
    volume_type = "gp3" # 최신 gp3 볼륨 타입 사용
  }

  user_data = <<_DATA
#!/bin/bash
sudo -u ec2-user -i <<'EC2_USER_SCRIPT'
curl -fsSL https://code-server.dev/install.sh | sh && sudo systemctl enable --now code-server@ec2-user
sleep 5
sed -i 's/127.0.0.1:8080/0.0.0.0:9090/g; s/auth: password/auth: none/g' /home/ec2-user/.config/code-server/config.yaml
EC2_USER_SCRIPT

echo 'export PS1="$(uname -m) \$ "' >> /home/ec2-user/.bashrc
sudo systemctl restart code-server@ec2-user
_DATA

  tags = {
    Name = "code-server-x86"
  }
}


/*
resource "aws_instance" "gitlab_box" {
  ami                         = data.aws_ami.al2023_x86_64.id
  instance_type               = var.gitlab_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  # IAM Instance Profile 연결 <--- EC2에 권한을 부여합니다.
  iam_instance_profile = aws_iam_instance_profile.eks_creator_profile.name

  // 루트 볼륨 크기를 30GB로 설정
  root_block_device {
    volume_size = 100 # GiB 단위
    volume_type = "gp3" # 최신 gp3 볼륨 타입 사용
  }

  user_data = <<_DATA
#!/bin/bash
# 1. DNF 자동 업데이트 프로세스 완료 대기 (보다 확실한 방법)
while fuser /var/lib/dnf/last_makecache >/dev/null 2>&1 ; do echo "Waiting for other dnf processes..."; sleep 5; done

# 2. 필수 의존성 사전 설치 및 캐시 초기화
sudo dnf clean all
sudo dnf install -y curl policycoreutils perl

# 3. GitLab 리포지토리 추가 (GPG 키를 미리 신뢰하도록 설정)
curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash

# 4. GPG 키 수동 임포트 (중요: 설치 중 중단 방지)
sudo dnf makecache -y

# 5. EC2 Metadata를 이용한 EXTERNAL_URL 설정
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s 169.254.169.254)
# DNS가 없는 경우 IP로 설정, 있는 경우 public-hostname 유지
export EXTERNAL_URL="http://$PUBLIC_IP"

# 6. GitLab 설치 (설치 실패 시 재시도 로직 추가)
MAX_RETRIES=3
for i in $(seq 1 $MAX_RETRIES); do
  sudo EXTERNAL_URL="$EXTERNAL_URL" dnf install -y gitlab-ce && break
  if [ $i -eq $MAX_RETRIES ]; then echo "GitLab installation failed after $MAX_RETRIES attempts"; exit 1; fi
  sudo dnf clean all
  sleep 10
done

# 7. 설정 및 실행
sudo gitlab-ctl reconfigure
_DATA

  tags = {
    Name = "gitlab-server"
  }
}

*/





