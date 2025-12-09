# 🔄 ArgoCD 모듈

## 📋 개요

이 모듈은 ArgoCD를 EKS 클러스터에 Helm Chart로 설치합니다.
GitOps 기반 Kubernetes 배포를 위한 CD(Continuous Delivery) 도구입니다.

---

## 🏗️ 아키텍처

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

---

## 📦 생성되는 컴포넌트

| 컴포넌트 | 역할 |
|----------|------|
| 🖥️ argocd-server | Web UI 및 API 서버 |
| 📂 argocd-repo-server | Git 저장소 연동 |
| 🔄 argocd-application-controller | 앱 동기화 관리 |
| 🗄️ argocd-redis | 캐시 서버 |
| ⚖️ argocd-ingress | ALB Ingress (선택) |
| 📋 argocd-application | GitOps 앱 자동 등록 (선택) |

---

## 🚀 사용법

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
  server_ingress_enabled = true
  server_ingress_class   = "alb"

  # GitOps Application 자동 등록 (선택사항)
  gitops_repo_url        = "https://github.com/<username>/petclinic-gitops.git"
  gitops_target_revision = "main"
  gitops_path            = "."
  app_name               = "petclinic"
  app_namespace          = "petclinic"

  tags = {
    Project     = var.project_name
    Environment = "production"
  }

  depends_on = [module.eks]
}
```

---

## 📥 입력 변수

| 변수명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `project_name` | string | ✅ | - | 프로젝트 이름 |
| `namespace` | string | | `argocd` | 설치 네임스페이스 |
| `chart_version` | string | | `5.51.6` | Helm Chart 버전 |
| `server_service_type` | string | | `ClusterIP` | Service 타입 |
| `server_replicas` | number | | `1` | Server 복제본 수 |
| `insecure` | bool | | `true` | HTTPS 비활성화 |
| `server_ingress_enabled` | bool | | `false` | Ingress 사용 여부 |
| `server_ingress_class` | string | | `alb` | Ingress Class |
| `gitops_repo_url` | string | | `""` | GitOps Repo URL |
| `gitops_target_revision` | string | | `main` | Git 브랜치/태그 |
| `gitops_path` | string | | `.` | 매니페스트 경로 |
| `app_name` | string | | `petclinic` | Application 이름 |
| `app_namespace` | string | | `petclinic` | 배포 네임스페이스 |

---

## 📤 출력 값

| 출력명 | 설명 |
|--------|------|
| `release_namespace` | ArgoCD 네임스페이스 |
| `app_version` | ArgoCD 버전 |
| `admin_password` | 초기 Admin 비밀번호 (sensitive) |
| `ingress_hostname` | ALB DNS 이름 |
| `access_instructions` | 접속 가이드 |

---

## 🔗 접속 방법

### 1️⃣ ALB Ingress 사용 (권장)

```bash
# ALB DNS 확인
kubectl get ingress -n argocd

# 브라우저 접속
http://<ALB_DNS_NAME>
```

### 2️⃣ Port Forward (로컬 테스트용)

```bash
# ArgoCD Server로 포트 포워딩
kubectl port-forward svc/argocd-server -n argocd 8080:80

# 브라우저 접속
open http://localhost:8080
```

### 3️⃣ 초기 로그인

```bash
# Admin 비밀번호 확인
terraform output -raw argocd_admin_password

# 로그인
# Username: admin
# Password: <위에서 확인한 비밀번호>
```

---

## 💻 ArgoCD CLI 사용

### 🔧 CLI 설치

```bash
# Mac
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/
```

### 🔑 CLI 로그인

```bash
argocd login <ALB_DNS> \
  --username admin \
  --password $(terraform output -raw argocd_admin_password) \
  --insecure
```

---

## 📁 GitOps Repository 연결

### 1️⃣ Repository 등록

```bash
# HTTPS 방식
argocd repo add https://github.com/<username>/<repo>.git \
  --username <github-username> \
  --password <github-token>

# SSH 방식
argocd repo add git@github.com:<username>/<repo>.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### 2️⃣ Application 생성 (CLI)

```bash
argocd app create petclinic \
  --repo https://github.com/<username>/petclinic-gitops.git \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace petclinic \
  --sync-policy automated
```

### 3️⃣ Application 생성 (YAML)

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
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: petclinic
  syncPolicy:
    automated:
      prune: true      # 삭제된 리소스 자동 제거
      selfHeal: true   # 수동 변경 자동 복구
    syncOptions:
      - CreateNamespace=true
```

---

## 🌐 외부 접근 설정

### ⚖️ ALB Ingress 사용 (권장)

```hcl
module "argocd" {
  # ...

  server_ingress_enabled = true
  server_ingress_class   = "alb"
}
```

### 🔌 NLB LoadBalancer 사용

```hcl
module "argocd" {
  # ...

  server_service_type = "LoadBalancer"
}
```

---

## 🔐 보안 권장사항

| 항목 | 설명 |
|------|------|
| 🔑 비밀번호 변경 | 초기 Admin 비밀번호는 즉시 변경 |
| 👥 RBAC 설정 | 프로젝트별 권한 분리 |
| 🔒 SSO 연동 | Dex를 통한 GitHub/Google SSO 설정 |
| 🔐 HTTPS 사용 | 프로덕션에서는 TLS 인증서 적용 |
| 🌐 IP 제한 | ALB에서 허용 IP 범위 설정 |

---

## ⚙️ Terraform 자동화 범위

이 모듈은 다음을 자동으로 생성합니다:

| 리소스 | Terraform | 설명 |
|--------|-----------|------|
| ArgoCD Helm Release | ✅ | Server, Repo, Controller, Redis |
| ArgoCD ALB Ingress | ✅ | 외부 접속용 ALB |
| ArgoCD Application | ✅ | GitOps Repo 자동 연결 |
| ClusterSecretStore | ❌ | GitOps에서 관리 (CRD 캐싱 문제) |
| ExternalSecret | ❌ | GitOps에서 관리 |

> 💡 **Tip**: ArgoCD 자체는 인프라이므로 Terraform으로 관리하고, 애플리케이션 배포는 GitOps로 관리합니다.

---

## 📊 상태 확인 명령어

```bash
# ArgoCD Pod 상태
kubectl get pods -n argocd

# ArgoCD Ingress 확인
kubectl get ingress -n argocd

# Application 목록
kubectl get applications -n argocd

# Application 상태 상세
argocd app get petclinic

# Sync 상태
argocd app sync petclinic
```

---

## 🛠️ 트러블슈팅

### ❌ Ingress가 생성되지 않음

```bash
# AWS Load Balancer Controller 확인
kubectl get pods -n kube-system | grep aws-load-balancer

# Ingress 이벤트 확인
kubectl describe ingress argocd-ingress -n argocd
```

### ❌ Application Sync 실패

```bash
# Application 상태 확인
argocd app get petclinic

# 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### ❌ Repository 연결 실패

```bash
# Repository 목록 확인
argocd repo list

# 연결 테스트
argocd repo get https://github.com/<username>/<repo>.git
```

---

## 📚 참고 자료

| 리소스 | 링크 |
|--------|------|
| 📖 ArgoCD 공식 문서 | [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io/) |
| 🎯 Argo Helm Charts | [github.com/argoproj/argo-helm](https://github.com/argoproj/argo-helm) |
| 📘 GitOps 패턴 | [gitops.tech](https://www.gitops.tech/) |
| 🎓 ArgoCD 튜토리얼 | [argo-cd.readthedocs.io/en/stable/getting_started](https://argo-cd.readthedocs.io/en/stable/getting_started/) |

---

## 📝 참고 사항

> 💡 **Tip**: `gitops_repo_url`을 설정하면 Terraform apply 시 ArgoCD Application이 자동으로 생성되어 GitOps Repo와 연결됩니다.

> ⚠️ **Warning**: ArgoCD Application을 Terraform으로 관리하면 순환 의존성 문제를 방지할 수 있습니다.

> 🔄 **Note**: ArgoCD는 기본적으로 3분마다 Git 저장소를 폴링합니다. Webhook을 설정하면 즉시 동기화됩니다.