# ============================================================================
# Jenkins 모듈 - outputs.tf
# ============================================================================
# 다른 모듈이나 루트 모듈에서 참조할 수 있는 출력값
# ============================================================================

# ----------------------------------------------------------------------------
# EC2 관련 출력
# ----------------------------------------------------------------------------
output "jenkins_instance_id" {
  description = "Jenkins EC2 인스턴스 ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_private_ip" {
  description = "Jenkins EC2 Private IP"
  value       = aws_instance.jenkins.private_ip
}

# ----------------------------------------------------------------------------
# Security Group 출력
# ----------------------------------------------------------------------------
output "jenkins_security_group_id" {
  description = "Jenkins EC2 Security Group ID"
  value       = aws_security_group.jenkins_sg.id
}

output "alb_security_group_id" {
  description = "Jenkins ALB Security Group ID"
  value       = aws_security_group.alb_sg.id
}

# ----------------------------------------------------------------------------
# ALB 관련 출력
# ----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "Jenkins ALB DNS Name (접속 URL)"
  value       = aws_lb.jenkins.dns_name
}

output "alb_arn" {
  description = "Jenkins ALB ARN"
  value       = aws_lb.jenkins.arn
}

output "alb_zone_id" {
  description = "Jenkins ALB Zone ID (Route53 Alias용)"
  value       = aws_lb.jenkins.zone_id
}

output "target_group_arn" {
  description = "Jenkins Target Group ARN"
  value       = aws_lb_target_group.jenkins.arn
}

# ----------------------------------------------------------------------------
# 접속 정보 (편의용)
# ----------------------------------------------------------------------------
output "jenkins_url" {
  description = "Jenkins 접속 URL"
  value       = "http://${aws_lb.jenkins.dns_name}"
}

output "github_webhook_url" {
  description = "GitHub Webhook 설정용 URL"
  value       = "http://${aws_lb.jenkins.dns_name}/github-webhook/"
}
