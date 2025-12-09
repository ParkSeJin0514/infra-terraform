# ============================================================================
# Jenkins 모듈 - variables.tf
# ============================================================================
# Jenkins EC2, ALB 구성에 필요한 입력 변수들
# ============================================================================

# ----------------------------------------------------------------------------
# 기본 설정
# ----------------------------------------------------------------------------
variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍에 사용)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "region" {
  description = "AWS 리전"
  type        = string
}

# ----------------------------------------------------------------------------
# EC2 설정
# ----------------------------------------------------------------------------
variable "ami" {
  description = "Jenkins EC2 AMI ID"
  type        = string
}

variable "instance_type" {
  description = "Jenkins EC2 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH 키페어 이름"
  type        = string
}

variable "private_subnet_id" {
  description = "Jenkins EC2가 배치될 Private Subnet ID"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS 볼륨 크기 (GB)"
  type        = number
  default     = 30
}

# ----------------------------------------------------------------------------
# ALB 설정
# ----------------------------------------------------------------------------
variable "public_subnet_ids" {
  description = "ALB가 배치될 Public Subnet ID 목록 (최소 2개 AZ)"
  type        = list(string)
}

variable "alb_certificate_arn" {
  description = "ALB HTTPS용 ACM 인증서 ARN (선택사항)"
  type        = string
  default     = ""
}

# ----------------------------------------------------------------------------
# Security Group 설정
# ----------------------------------------------------------------------------
variable "bastion_security_group_id" {
  description = "Bastion Security Group ID (SSH 접근 허용용)"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "Jenkins ALB 접근을 허용할 CIDR 블록 (예: 회사 IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ----------------------------------------------------------------------------
# IAM 설정
# ----------------------------------------------------------------------------
variable "iam_instance_profile" {
  description = "Jenkins EC2에 연결할 IAM Instance Profile 이름"
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------
# 태그
# ----------------------------------------------------------------------------
variable "tags" {
  description = "모든 리소스에 적용할 태그"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# 의존성 (암묵적)
# ----------------------------------------------------------------------------
variable "nat_gateway_ids" {
  description = "NAT Gateway IDs - Jenkins EC2 생성 전 NAT 준비 보장"
  type        = map(string)
  default     = {}
}
