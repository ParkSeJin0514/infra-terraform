# ============================================================================
# outputs.tf - 프로젝트 출력 값
# ============================================================================
# terraform apply 후 확인할 수 있는 주요 정보들
# ============================================================================

# ============================================================================
# Network Outputs
# ============================================================================

# ============================================================================
# EC2 Outputs
# ============================================================================

output "bastion_public_ip" {
  description = "Bastion Host Public IP (SSH 접속용)"
  value       = module.ec2.bastion_public_ip
}

output "mgmt_private_ip" {
  description = "Management Instance Private IP"
  value       = module.ec2.mgmt_private_ip
}

# ============================================================================
# EKS Outputs
# ============================================================================

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_id
}

output "eks_cluster_version" {
  description = "EKS Kubernetes 버전"
  value       = module.eks.cluster_version
}

output "kubeconfig_command" {
  description = "kubeconfig 설정 명령어"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ap-northeast-2"
}

# ============================================================================
# RDS Outputs
# ============================================================================

output "rds_address" {
  description = "RDS 호스트명"
  value       = module.db.address
}

output "rds_database_name" {
  description = "생성된 데이터베이스 이름"
  value       = module.db.db_name
}

# ============================================================================
# Jenkins Outputs
# ============================================================================

output "jenkins_url" {
  description = "Jenkins 접속 URL"
  value       = module.jenkins.jenkins_url
}

output "jenkins_alb_dns" {
  description = "Jenkins ALB DNS Name"
  value       = module.jenkins.alb_dns_name
}

output "jenkins_private_ip" {
  description = "Jenkins EC2 Private IP"
  value       = module.jenkins.jenkins_private_ip
}

output "github_webhook_url" {
  description = "GitHub Webhook 설정용 URL"
  value       = module.jenkins.github_webhook_url
}

# ============================================================================
# ArgoCD Outputs
# ============================================================================

output "argocd_namespace" {
  description = "ArgoCD 네임스페이스"
  value       = module.argocd.release_namespace
}

output "argocd_version" {
  description = "ArgoCD 버전"
  value       = module.argocd.app_version
}

output "argocd_admin_password" {
  description = "ArgoCD 초기 Admin 비밀번호"
  value       = module.argocd.admin_password
  sensitive   = true
}

# ============================================================================
# External Secrets Outputs
# ============================================================================

output "secrets_manager_secret_arn" {
  description = "AWS Secrets Manager Secret ARN"
  value       = aws_secretsmanager_secret.db.arn
}

output "secrets_manager_secret_name" {
  description = "AWS Secrets Manager Secret Name"
  value       = aws_secretsmanager_secret.db.name
}

output "external_secrets_role_arn" {
  description = "External Secrets IRSA Role ARN"
  value       = module.external_secrets_irsa.iam_role_arn
}

# ============================================================================
# 접속 가이드
# ============================================================================

output "connection_guide" {
  description = "접속 가이드"
  value       = <<-EOT

  ============================================
  📋 접속 가이드
  ============================================

  1️⃣  Bastion Host SSH 접속
      ssh -i test.pem ubuntu@${module.ec2.bastion_public_ip}

  2️⃣  Management Instance 접속 (Bastion 경유)
      ssh -i test.pem -J ubuntu@${module.ec2.bastion_public_ip} ubuntu@${module.ec2.mgmt_private_ip}

  3️⃣  Jenkins 접속 (Bastion 경유)
      ssh -i test.pem -J ubuntu@${module.ec2.bastion_public_ip} ec2-user@${module.jenkins.jenkins_private_ip}

  4️⃣  kubeconfig 설정 (Management Instance에서)
      aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ap-northeast-2

  5️⃣  RDS 접속 정보
      Host: ${module.db.address}
      Port: ${module.db.port}
      Database: ${module.db.db_name}
      
      MySQL 접속 (Management Instance에서)
      mysql -h ${module.db.address} -P ${module.db.port} -u admin -p

  6️⃣  Jenkins 접속 정보
      URL: ${module.jenkins.jenkins_url}
      GitHub Webhook: ${module.jenkins.github_webhook_url}
      
      초기 비밀번호 확인 (Jenkins EC2에서):
      sudo cat /var/lib/jenkins/secrets/initialAdminPassword

  7️⃣  ArgoCD 접속 정보
      네임스페이스: ${module.argocd.release_namespace}
      
      Port Forward (Management Instance에서):
      kubectl port-forward svc/argocd-server -n argocd 8080:80
      
      로그인 정보:
      Username: admin
      Password: terraform output -raw argocd_admin_password

  8️⃣  External Secrets 확인
      # Operator 상태 확인
      kubectl get pods -n external-secrets
      
      # CRD 설치 확인
      kubectl get crd | grep external-secrets
      
      # Secrets Manager Secret 이름
      ${aws_secretsmanager_secret.db.name}
      
      ⚠️ ClusterSecretStore, ExternalSecret은 GitOps repo에서 설정하세요!
  EOT
}