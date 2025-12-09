# ============================================================================
# variables.tf - 프로젝트 전체 변수 정의
# ============================================================================
# terraform.tfvars에서 값을 설정하면 여기서 정의된 변수에 할당됩니다.
# default 값이 있는 변수는 tfvars에서 생략 가능합니다.
# ============================================================================

# ============================================================================
# 네트워크 변수
# ============================================================================

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록 (예: 10.0.0.0/16)"
}

variable "az_count" {
  type        = number
  description = "사용할 가용영역 개수 (1~4)"
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "az_count는 1에서 4 사이여야 합니다."
  }
}

# ============================================================================
# 공통 변수
# ============================================================================

variable "project_name" {
  type        = string
  description = "프로젝트 이름 - 모든 리소스 명명에 prefix로 사용"
}

variable "region" {
  type        = string
  description = "AWS 리전 (예: ap-northeast-2)"
  default     = "ap-northeast-2"
}

# ============================================================================
# EC2 인스턴스 변수
# ============================================================================

variable "ami" {
  type        = string
  description = "EC2 인스턴스 AMI ID"
}

variable "bastion_instance_type" {
  type        = string
  description = "Bastion Host 인스턴스 타입 (예: t3.micro)"
}

variable "mgmt_instance_type" {
  type        = string
  description = "Management 인스턴스 타입 (예: t3.small)"
}

variable "key_name" {
  type        = string
  description = "SSH 접근용 Key Pair 이름"
  default     = null
}

# AMI 필터 - data.tf에서 동적 AMI 조회에 사용
variable "ubuntu_ami_filters" {
  type = list(object({
    name   = string
    values = list(string)
  }))
  description = "Ubuntu AMI 검색 필터"
}

# ============================================================================
# EKS 변수
# ============================================================================

variable "eks_version" {
  type        = string
  description = "EKS Kubernetes 버전"
  default     = "1.31"
}

variable "eks_instance_types" {
  type        = list(string)
  description = "Worker Node 인스턴스 타입"
  default     = ["t3.medium"]
}

variable "eks_capacity_type" {
  type        = string
  description = "용량 타입: ON_DEMAND (안정적) 또는 SPOT (비용 절감)"
  default     = "ON_DEMAND"
}

variable "eks_disk_size" {
  type        = number
  description = "Worker Node EBS 볼륨 크기 (GB)"
  default     = 50
}

# 스케일링 설정
variable "eks_desired_size" {
  type        = number
  description = "원하는 Worker Node 수"
  default     = 2
}

variable "eks_max_size" {
  type        = number
  description = "최대 Worker Node 수 (Auto Scaling 상한)"
  default     = 4
}

variable "eks_min_size" {
  type        = number
  description = "최소 Worker Node 수 (Auto Scaling 하한)"
  default     = 1
}

# 롤링 업데이트 설정
# 33% = 노드 3대일 때 1대씩 업데이트
variable "eks_max_unavailable_percentage" {
  type        = number
  description = "업데이트 시 동시 중단 가능한 노드 비율 (%)"
  default     = 33
}

# kubelet 추가 옵션
# --max-pods: 노드당 최대 Pod 수 (기본값은 ENI 기반으로 제한됨)
variable "eks_kubelet_extra_args" {
  type        = string
  description = "kubelet 추가 인자 (예: --max-pods=110)"
  default     = "--max-pods=110"
}

# Kubernetes 노드 레이블
variable "eks_node_labels" {
  type        = map(string)
  description = "Worker Node에 추가할 Kubernetes 레이블"
  default     = {}
}

# Kubernetes 노드 Taint
# effect: NoSchedule, NoExecute, PreferNoSchedule
variable "eks_node_taints" {
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  description = "Worker Node에 적용할 Taint"
  default     = []
}

# Control Plane 로깅
variable "eks_cluster_log_types" {
  type        = list(string)
  description = "CloudWatch로 전송할 Control Plane 로그 유형"
  default     = ["api", "audit", "authenticator"]
}

# ============================================================================
# RDS 변수
# ============================================================================

variable "db_engine" {
  type        = string
  description = "데이터베이스 엔진"
  default     = "mysql"
}

variable "db_engine_version" {
  type        = string
  description = "데이터베이스 엔진 버전"
  default     = "8.0"
}

variable "db_parameter_group_family" {
  type        = string
  description = "파라미터 그룹 패밀리"
  default     = "mysql8.0"
}

variable "db_instance_class" {
  type        = string
  description = "RDS 인스턴스 클래스"
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "할당할 스토리지 크기 (GB)"
  default     = 20
}

variable "db_max_allocated_storage" {
  type        = number
  description = "Auto Scaling 최대 스토리지 크기 (GB). 0이면 비활성화"
  default     = 100
}

variable "db_storage_type" {
  type        = string
  description = "스토리지 타입 (gp2, gp3, io1)"
  default     = "gp3"
}

variable "db_storage_encrypted" {
  type        = bool
  description = "스토리지 암호화 여부"
  default     = true
}

variable "db_name" {
  type        = string
  description = "생성할 데이터베이스 이름"
  default     = "petclinic"
}

variable "db_username" {
  type        = string
  description = "마스터 사용자 이름"
  default     = "admin"
}

variable "db_password" {
  type        = string
  description = "마스터 사용자 비밀번호 (8자 이상)"
  sensitive   = true
  default     = "123456789"
}

variable "db_port" {
  type        = number
  description = "데이터베이스 포트"
  default     = 3306
}

variable "db_multi_az" {
  type        = bool
  description = "Multi-AZ 배포 여부"
  default     = false
}

variable "db_deletion_protection" {
  type        = bool
  description = "삭제 보호 활성화 (프로덕션에서 true 권장)"
  default     = false
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "삭제 시 최종 스냅샷 생략"
  default     = true
}

# ============================================================================
# Jenkins 변수
# ============================================================================

variable "jenkins_instance_type" {
  type        = string
  description = "Jenkins EC2 인스턴스 타입"
  default     = "t3.medium"
}

# ============================================================================
# ArgoCD 변수
# ============================================================================

variable "argocd_chart_version" {
  type        = string
  description = "ArgoCD Helm Chart 버전"
  default     = "5.51.6"
}

variable "gitops_repo_url" {
  description = "GitOps Repository URL"
  type        = string
  default     = "https://github.com/ParkSeJin0514/petclinic-gitops.git"
}