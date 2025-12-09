# ============================================================================
# ArgoCD 모듈 - main.tf
# ============================================================================
# ArgoCD를 EKS 클러스터에 Helm Chart로 설치하고,
# ALB Ingress와 GitOps Application까지 자동 생성합니다.
#
# 생성되는 리소스:
#   1. ArgoCD Helm Release (Server, Repo Server, Controller, Redis)
#   2. ALB Ingress (외부 접속용)
#   3. ArgoCD Application (GitOps 자동 배포)
# ============================================================================

# ============================================================================
# 1. ArgoCD Helm Release
# ============================================================================
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  timeout = 600
  wait    = true

  values = [
    yamlencode({
      global = {
        additionalLabels = {
          "app.kubernetes.io/managed-by" = "terraform"
          "project"                      = var.project_name
        }
      }

      server = {
        replicas = var.server_replicas

        service = {
          type = var.server_service_type
        }

        # HTTPS 비활성화 (ALB에서 TLS 처리)
        extraArgs = var.insecure ? ["--insecure"] : []
      }

      repoServer = {
        replicas = var.repo_server_replicas
      }

      controller = {
        replicas = 1
      }

      redis = {
        enabled = true
      }

      dex = {
        enabled = false
      }

      notifications = {
        enabled = false
      }

      applicationSet = {
        enabled = true
      }

      configs = {
        ssh = {
          knownHosts = <<-EOF
            github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
            github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
            github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
          EOF
        }
        
        params = {
          "server.insecure" = var.insecure
        }
      }
    })
  ]
}

# ============================================================================
# 2. ArgoCD ALB Ingress
# ============================================================================
resource "kubernetes_ingress_v1" "argocd" {
  count = var.server_ingress_enabled ? 1 : 0

  metadata {
    name      = "argocd-ingress"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/tags"             = "Project=${var.project_name},Environment=production"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# ============================================================================
# 3. ArgoCD Application (GitOps 자동 배포)
# ============================================================================
resource "kubernetes_manifest" "argocd_application" {
  count = var.gitops_repo_url != "" ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.app_name
      namespace = var.namespace
    }
    spec = {
      project = "default"
      
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = var.gitops_path
      }
      
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      
      syncPolicy = {
        automated = {
          prune    = true    # 삭제된 리소스 자동 정리
          selfHeal = true    # 수동 변경 시 자동 복구
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# ============================================================================
# 4. ArgoCD Admin 비밀번호 조회
# ============================================================================
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}