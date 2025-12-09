# Jenkins 모듈

## 개요

이 모듈은 CI/CD 파이프라인용 Jenkins 서버를 Private Subnet에 배포하고,
ALB를 통해 외부 접근(GitHub Webhook, Web UI)을 제공합니다.

## 아키텍처

```
                    ┌─────────────────────────────────────────┐
                    │              VPC                         │
                    │                                          │
[Internet]          │   ┌─────────────┐    ┌───────────────┐  │
    │               │   │ Public      │    │ Private       │  │
    │               │   │ Subnet      │    │ Subnet        │  │
    ▼               │   │             │    │               │  │
┌───────┐           │   │  ┌─────┐    │    │  ┌─────────┐  │  │
│GitHub │──Webhook──│───│─▶│ ALB │────│────│─▶│ Jenkins │  │  │
│       │           │   │  └─────┘    │    │  │  EC2    │  │  │
└───────┘           │   │             │    │  └─────────┘  │  │
                    │   └─────────────┘    └───────────────┘  │
                    └─────────────────────────────────────────┘
```

## 생성 리소스

| 리소스 | 이름 | 설명 |
|--------|------|------|
| Security Group | `{project}-jenkins-alb-sg` | ALB용 (80, 443 허용) |
| Security Group | `{project}-jenkins-sg` | Jenkins EC2용 |
| ALB | `{project}-jenkins-alb` | Application Load Balancer |
| Target Group | `{project}-jenkins-tg` | Jenkins 8080 포트 |
| EC2 Instance | `{project}-jenkins` | Jenkins 서버 |

## 사용법

```hcl
module "jenkins" {
  source = "./modules/jenkins"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  region       = var.region

  # EC2 설정
  ami               = var.ami
  instance_type     = "t3.medium"
  key_name          = var.key_name
  private_subnet_id = module.network.private_mgmt_subnet_id[0]

  # ALB 설정 (최소 2개 AZ의 Public Subnet 필요)
  public_subnet_ids = module.network.public_subnet_id

  # Security Group
  bastion_security_group_id = module.ec2.bastion_security_group_id

  # IAM (선택)
  iam_instance_profile = aws_iam_instance_profile.jenkins.name

  # HTTPS (선택)
  alb_certificate_arn = aws_acm_certificate.jenkins.arn

  # NAT Gateway 의존성
  nat_gateway_ids = module.network.nat_gateway_ids

  tags = {
    Project     = var.project_name
    Environment = "production"
  }
}
```

## 입력 변수

| 변수명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `project_name` | string | ✓ | - | 프로젝트 이름 |
| `vpc_id` | string | ✓ | - | VPC ID |
| `region` | string | ✓ | - | AWS 리전 |
| `ami` | string | ✓ | - | EC2 AMI ID |
| `instance_type` | string | | `t3.medium` | 인스턴스 타입 |
| `key_name` | string | ✓ | - | SSH 키페어 |
| `private_subnet_id` | string | ✓ | - | Jenkins EC2 서브넷 |
| `public_subnet_ids` | list | ✓ | - | ALB 서브넷 (2개 이상) |
| `bastion_security_group_id` | string | ✓ | - | Bastion SG ID |
| `alb_certificate_arn` | string | | `""` | HTTPS 인증서 ARN |
| `iam_instance_profile` | string | | `null` | IAM 프로파일 |
| `root_volume_size` | number | | `30` | EBS 볼륨 크기 (GB) |

## 출력 값

| 출력명 | 설명 |
|--------|------|
| `jenkins_instance_id` | Jenkins EC2 인스턴스 ID |
| `jenkins_private_ip` | Jenkins Private IP |
| `jenkins_security_group_id` | Jenkins SG ID |
| `alb_dns_name` | ALB DNS 이름 |
| `jenkins_url` | Jenkins 접속 URL |
| `github_webhook_url` | GitHub Webhook URL |

## Jenkins 초기 설정

### 1. 초기 관리자 비밀번호 확인

```bash
# Bastion 경유 접속
ssh -i key.pem ec2-user@<bastion-ip>
ssh -i key.pem ec2-user@<jenkins-private-ip>

# 초기 비밀번호 확인
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 2. Jenkins 접속

```
http://<ALB_DNS_NAME>
```

### 3. 필수 플러그인 설치

- Git Plugin
- GitHub Plugin
- Pipeline Plugin
- Docker Pipeline Plugin
- Amazon ECR Plugin
- Kubernetes CLI Plugin

## GitHub Webhook 설정

1. GitHub Repository → Settings → Webhooks
2. Add webhook:
   - Payload URL: `http://<ALB_DNS>/github-webhook/`
   - Content type: `application/json`
   - Events: `Just the push event`

## 보안 고려사항

- Jenkins EC2는 Private Subnet에 배치 (외부 직접 접근 불가)
- ALB를 통해서만 8080 포트 접근 가능
- SSH 접근은 Bastion을 통해서만 가능
- 운영 환경에서는 `allowed_cidr_blocks`로 IP 제한 권장
- HTTPS 사용 권장 (`alb_certificate_arn` 설정)

## 설치되는 도구

- Jenkins (LTS)
- Java 17 (Amazon Corretto)
- Docker
- AWS CLI v2
- kubectl
- Git
