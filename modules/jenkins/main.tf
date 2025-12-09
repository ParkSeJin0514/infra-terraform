# ============================================================================
# Jenkins 모듈 - main.tf
# ============================================================================
# Jenkins CI 서버를 Private Subnet에 배포하고,
# ALB를 통해 GitHub Webhook과 Web UI 접근을 제공합니다.
#
# 아키텍처:
#   Internet → ALB (Public) → Jenkins EC2 (Private)
#
# 생성 리소스:
#   - Security Group 2개 (ALB SG, Jenkins SG)
#   - Application Load Balancer
#   - Target Group + Listener
#   - EC2 Instance (Jenkins)
# ============================================================================

# ============================================================================
# 1. ALB Security Group
# ============================================================================
# ALB용 Security Group
# 인터넷에서 HTTP(80), HTTPS(443) 접근 허용
# ============================================================================

resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-jenkins-alb-sg"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-alb-sg"
  })
}

# Inbound: HTTP (80)
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  tags = {
    Name = "${var.project_name}-jenkins-alb-http"
  }
}

# Inbound: HTTPS (443) - 인증서가 있는 경우
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = var.alb_certificate_arn != "" ? 1 : 0
  security_group_id = aws_security_group.alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "${var.project_name}-jenkins-alb-https"
  }
}

# Outbound: Jenkins EC2로 전달
resource "aws_vpc_security_group_egress_rule" "alb_to_jenkins" {
  security_group_id = aws_security_group.alb_sg.id

  referenced_security_group_id = aws_security_group.jenkins_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"

  tags = {
    Name = "${var.project_name}-jenkins-alb-egress"
  }
}

# ============================================================================
# 2. Jenkins EC2 Security Group
# ============================================================================
# Jenkins 서버용 Security Group
# - ALB에서 8080 포트 접근 허용
# - Bastion에서 SSH 접근 허용
# ============================================================================

resource "aws_security_group" "jenkins_sg" {
  name_prefix = "${var.project_name}-jenkins-sg"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-sg"
  })
}

# Inbound: ALB → Jenkins (8080)
resource "aws_vpc_security_group_ingress_rule" "jenkins_from_alb" {
  security_group_id = aws_security_group.jenkins_sg.id

  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"

  tags = {
    Name = "${var.project_name}-jenkins-from-alb"
  }
}

# Inbound: Bastion → Jenkins (SSH)
resource "aws_vpc_security_group_ingress_rule" "jenkins_ssh_from_bastion" {
  security_group_id = aws_security_group.jenkins_sg.id

  referenced_security_group_id = var.bastion_security_group_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"

  tags = {
    Name = "${var.project_name}-jenkins-ssh-from-bastion"
  }
}

# Outbound: All Traffic (인터넷 접근 - NAT 경유)
# GitHub, ECR, Docker Hub 등 외부 서비스 접근 필요
resource "aws_vpc_security_group_egress_rule" "jenkins_outbound" {
  security_group_id = aws_security_group.jenkins_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${var.project_name}-jenkins-outbound"
  }
}

# ============================================================================
# 3. Application Load Balancer
# ============================================================================
# Public Subnet에 배치되어 인터넷 트래픽 수신
# GitHub Webhook 요청을 Jenkins로 전달
# ============================================================================

resource "aws_lb" "jenkins" {
  name               = "${var.project_name}-jenkins-alb"
  internal           = false  # 인터넷 facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-alb"
  })
}

# ============================================================================
# 4. Target Group
# ============================================================================
# Jenkins EC2를 대상으로 하는 Target Group
# Health Check로 Jenkins 상태 모니터링
# ============================================================================

resource "aws_lb_target_group" "jenkins" {
  name     = "${var.project_name}-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/login"  # Jenkins 로그인 페이지로 Health Check
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-tg"
  })
}

# Target Group에 Jenkins EC2 등록
resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = aws_instance.jenkins.id
  port             = 8080
}

# ============================================================================
# 5. ALB Listener
# ============================================================================
# HTTP(80) 리스너 - HTTPS가 없는 경우 기본 사용
# HTTPS(443) 리스너 - ACM 인증서가 있는 경우 사용
# ============================================================================

# HTTP Listener (기본)
resource "aws_lb_listener" "jenkins_http" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-http-listener"
  })
}

# HTTPS Listener (선택사항 - 인증서가 있는 경우)
resource "aws_lb_listener" "jenkins_https" {
  count             = var.alb_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-https-listener"
  })
}

# ============================================================================
# 6. Jenkins EC2 Instance
# ============================================================================
# Private Subnet에 배치 (보안)
# User Data로 Jenkins 자동 설치
# Docker, AWS CLI, kubectl 등 CI/CD 도구 포함
# ============================================================================

resource "aws_instance" "jenkins" {
  ami           = var.ami
  instance_type = var.instance_type

  # Private Subnet에 배치 → ALB 통해서만 접근
  subnet_id = var.private_subnet_id

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = var.key_name

  # IAM Instance Profile (ECR Push, EKS 접근 등)
  iam_instance_profile = var.iam_instance_profile

  # Root Block Device
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Jenkins 설치 스크립트
  user_data_base64 = base64encode(
    templatefile("${path.module}/userdata.tftpl", {
      region = var.region
    })
  )

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins"
  })

  # Lifecycle - 인스턴스 교체 시 새 인스턴스 먼저 생성
  lifecycle {
    create_before_destroy = true
  }
}
