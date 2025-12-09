# ============================================================================
# ArgoCD 모듈 - variables.tf
# ============================================================================

# ----------------------------------------------------------------------------
# 기본 설정
# ----------------------------------------------------------------------------
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "namespace" {
  description = "ArgoCD 네임스페이스"
  type        = string
  default     = "argocd"
}

variable "create_namespace" {
  description = "네임스페이스 자동 생성"
  type        = bool
  default     = true
}

# ----------------------------------------------------------------------------
# Helm Chart 설정
# ----------------------------------------------------------------------------
variable "chart_version" {
  description = "ArgoCD Helm Chart 버전"
  type        = string
  default     = "5.51.6"
}

# ----------------------------------------------------------------------------
# Server 설정
# ----------------------------------------------------------------------------
variable "server_service_type" {
  description = "ArgoCD Server Service 타입"
  type        = string
  default     = "ClusterIP"
}

variable "server_replicas" {
  description = "ArgoCD Server 복제본 수"
  type        = number
  default     = 1
}

variable "repo_server_replicas" {
  description = "Repo Server 복제본 수"
  type        = number
  default     = 1
}

variable "insecure" {
  description = "HTTPS 비활성화 (ALB 사용 시 true)"
  type        = bool
  default     = true
}

# ----------------------------------------------------------------------------
# Ingress 설정
# ----------------------------------------------------------------------------
variable "server_ingress_enabled" {
  description = "ALB Ingress 활성화"
  type        = bool
  default     = true
}

variable "server_ingress_class" {
  description = "Ingress Class"
  type        = string
  default     = "alb"
}

# ----------------------------------------------------------------------------
# GitOps Application 설정
# ----------------------------------------------------------------------------
variable "app_name" {
  description = "ArgoCD Application 이름"
  type        = string
  default     = "petclinic"
}

variable "app_namespace" {
  description = "애플리케이션 배포 네임스페이스"
  type        = string
  default     = "petclinic"
}

variable "gitops_repo_url" {
  description = "GitOps Repository URL"
  type        = string
  default     = ""
}

variable "gitops_target_revision" {
  description = "Git Branch/Tag"
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "매니페스트 경로"
  type        = string
  default     = "."
}

# ----------------------------------------------------------------------------
# 기타
# ----------------------------------------------------------------------------
variable "admin_password_secret_name" {
  description = "Admin 비밀번호 Secret"
  type        = string
  default     = ""
}

variable "tags" {
  description = "태그"
  type        = map(string)
  default     = {}
}