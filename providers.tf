# ============================================================================
# providers.tf - Provider 설정
# ============================================================================
# Terraform이 AWS, Kubernetes, Helm 리소스를 관리하기 위한 Provider 설정
# ============================================================================

# ============================================================================
# AWS Provider
# ============================================================================
# AWS 리소스 생성/관리에 사용
# 인증: AWS CLI 설정 (~/.aws/credentials) 또는 환경변수 사용
# ============================================================================
provider "aws" {
  region = var.region # 변수로 관리

  # 모든 리소스에 자동으로 추가되는 기본 태그
  default_tags {
    tags = {
      Managed = "terraform"
    }
  }
}

# ============================================================================
# Kubernetes Provider
# ============================================================================
# EKS 클러스터의 Kubernetes 리소스 관리에 사용
# 이 프로젝트에서는 aws-auth ConfigMap, ServiceAccount 관리에 사용
#
# 인증 방식: exec 플러그인
#   - aws eks get-token 명령으로 임시 토큰 발급
#   - IAM 자격증명으로 클러스터 인증
# ============================================================================
provider "kubernetes" {
  # EKS API Server 주소
  host = module.eks.cluster_endpoint

  # 클러스터 CA 인증서 (Base64 디코딩 필요)
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # exec 플러그인으로 토큰 발급
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

# ============================================================================
# Helm Provider
# ============================================================================
# Helm Chart를 이용한 Kubernetes 애플리케이션 배포에 사용
# 이 프로젝트에서는 ALB Controller, EFS CSI Driver 설치에 사용
# ============================================================================
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
    }
  }
}