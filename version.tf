# ============================================================================
# version.tf - Terraform 및 Provider 버전 제약
# ============================================================================
# 이 파일은 Terraform 버전과 사용할 Provider의 버전을 지정합니다.
# 버전을 명시하면 예기치 않은 호환성 문제를 방지할 수 있습니다.
# ============================================================================

terraform {
  # Terraform 최소 버전
  required_version = ">= 1.8"

  # 필수 Provider 및 버전
  required_providers {
    # AWS Provider
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # Kubernetes Provider
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }

    # Helm Provider (ALB Controller, EFS CSI Driver 설치용)
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }

    # TLS Provider (OIDC thumbprint 조회용)
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}