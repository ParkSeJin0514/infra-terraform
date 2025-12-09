# ArgoCD 모듈

## 개요

이 모듈은 ArgoCD를 EKS 클러스터에 Helm Chart로 설치합니다.
GitOps 기반 Kubernetes 배포를 위한 CD(Continuous Delivery) 도구입니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│  EKS Cluster                                                │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  argocd namespace                                     │  │
│  │                                                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │  │
│  │  │ argocd-     │  │ argocd-     │  │ argocd-app   │  │  │
│  │  │ server      │  │ repo-server │  │ controller   │  │  │
│  │  │ (Web UI)    │  │ (Git 연동)  │  │ (동기화)     │  │  │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  │  │
│  │         │                                             │  │
│  │         ▼                                             │  │
│  │  ┌─────────────┐                                      │  │
│  │  │ argocd-     │                                      │  │
│  │  │ redis       │                                      │  │
│  │  └─────────────┘                                      │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  default namespace (또는 다른 앱 네임스페이스)          │  │
│  │                                                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │ App Pod 1   │  │ App Pod 2   │  │ App Pod 3   │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  │         ↑                ↑                ↑          │  │
│  │         └────────────────┴────────────────┘          │  │
│  │                    ArgoCD가 관리                      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↑
                              │ Git 동기화
                              ▼
                    ┌─────────────────┐
                    │  GitOps Repo    │
                    │  (GitHub)       │
                    └─────────────────┘
```

## 사용법

```hcl
module "argocd" {
  source = "./modules/argocd"

  project_name = var.project_name
  namespace    = "argocd"

  # Helm Chart 버전
  chart_version = "5.51.6"

  # Server 설정
  server_service_type = "ClusterIP"
  server_replicas     = 1
  insecure            = true  # HTTP 사용 (ALB에서 HTTPS 처리)

  # Ingress 설정 (선택사항)
  server_ingress_enabled = false
  # server_ingress_hosts   = ["argocd.example.com"]

  tags = {
    Project     = var.project_name
    Environment = "production"
  }

  depends_on = [module.eks]
}
```

## 입력 변수

| 변수명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `project_name` | string | ✓ | - | 프로젝트 이름 |
| `namespace` | string | | `argocd` | 설치 네임스페이스 |
| `chart_version` | string | | `5.51.6` | Helm Chart 버전 |
| `server_service_type` | string | | `ClusterIP` | Service 타입 |
| `server_replicas` | number | | `1` | Server 복제본 수 |
| `insecure` | bool | | `true` | HTTPS 비활성화 |
| `server_ingress_enabled` | bool | | `false` | Ingress 사용 |
| `server_ingress_hosts` | list | | `[]` | Ingress 호스트 |

## 출력 값

| 출력명 | 설명 |
|--------|------|
| `release_namespace` | ArgoCD 네임스페이스 |
| `app_version` | ArgoCD 버전 |
| `admin_password` | 초기 Admin 비밀번호 (sensitive) |
| `access_instructions` | 접속 가이드 |

## 접속 방법

### 1. Port Forward (로컬 테스트용)

```bash
# ArgoCD Server로 포트 포워딩
kubectl port-forward svc/argocd-server -n argocd 8080:80

# 브라우저 접속
open http://localhost:8080
```

### 2. 초기 로그인

```bash
# Admin 비밀번호 확인
terraform output -raw argocd_admin_password

# 로그인
Username: admin
Password: <위에서 확인한 비밀번호>
```

### 3. ArgoCD CLI 설치 및 로그인

```bash
# CLI 설치 (Mac)
brew install argocd

# CLI 로그인
argocd login localhost:8080 \
  --username admin \
  --password $(terraform output -raw argocd_admin_password) \
  --insecure
```

## GitOps Repository 연결

### 1. Repository 등록

```bash
# HTTPS 방식
argocd repo add https://github.com/<username>/<repo>.git \
  --username <github-username> \
  --password <github-token>

# SSH 방식
argocd repo add git@github.com:<username>/<repo>.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### 2. Application 생성

```bash
argocd app create petclinic \
  --repo https://github.com/<username>/petclinic-gitops.git \
  --path overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

### 3. 또는 Application YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: petclinic
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<username>/petclinic-gitops.git
    targetRevision: main
    path: overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 외부 접근 설정 (선택사항)

### ALB Ingress 사용

```hcl
module "argocd" {
  # ...

  server_ingress_enabled = true
  server_ingress_class   = "alb"
  server_ingress_hosts   = ["argocd.your-domain.com"]
}
```

### NLB LoadBalancer 사용

```hcl
module "argocd" {
  # ...

  server_service_type = "LoadBalancer"
}
```

## 보안 권장사항

1. **비밀번호 변경**: 초기 Admin 비밀번호는 즉시 변경
2. **RBAC 설정**: 프로젝트별 권한 분리
3. **SSO 연동**: Dex를 통한 GitHub/Google SSO 설정
4. **HTTPS 사용**: 프로덕션에서는 TLS 인증서 적용

## 참고 자료

- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Argo Helm Charts](https://github.com/argoproj/argo-helm)
- [GitOps 패턴](https://www.gitops.tech/)
