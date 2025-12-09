# ============================================================================
# ArgoCD 모듈 - outputs.tf
# ============================================================================

output "release_name" {
  description = "Helm Release 이름"
  value       = helm_release.argocd.name
}

output "release_namespace" {
  description = "ArgoCD 네임스페이스"
  value       = helm_release.argocd.namespace
}

output "app_version" {
  description = "ArgoCD 버전"
  value       = helm_release.argocd.metadata[0].app_version
}

output "admin_password" {
  description = "ArgoCD Admin 비밀번호"
  value       = data.kubernetes_secret.argocd_admin.data["password"]
  sensitive   = true
}

output "ingress_hostname" {
  description = "ArgoCD ALB DNS (생성 후 kubectl get ingress -n argocd로 확인)"
  value       = var.server_ingress_enabled ? "kubectl get ingress -n argocd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'" : "Ingress disabled"
}

output "access_instructions" {
  description = "접속 가이드"
  value       = <<-EOT
    
    ============================================
    🚀 ArgoCD 접속 가이드
    ============================================
    
    1️⃣  ALB DNS 확인 (2-3분 소요)
        kubectl get ingress -n ${helm_release.argocd.namespace}
    
    2️⃣  브라우저 접속
        http://<ALB_DNS>
    
    3️⃣  로그인 정보
        Username: admin
        Password: terraform output -raw argocd_admin_password
    
    4️⃣  Application 상태 확인
        kubectl get applications -n argocd
    
    ============================================
  EOT
}