# Terraform을 이용한 CSP Infra 자동화 구축

Infra를 Terraform으로 프로비저닝하는 Infrastructure as Code(IaC) 프로젝트입니다.

## ✨ 주요 특징

- **모듈화된 구조**: Network, EC2, EKS, DB, Jenkins, ArgoCD 모듈로 분리
- **Multi-AZ 구성**: 2개 가용영역(ap-northeast-2a, ap-northeast-2c) 배포
- **보안 강화**: Private Subnet에 워커 노드 및 Jenkins 배치, Bastion Host를 통한 접근
- **Ubuntu 24.04 기반**: EKS 워커 노드에 Ubuntu 24.04 LTS 사용
- **자동화**: aws-auth ConfigMap 자동 구성, kubeconfig 자동 설정
- **Mgmt 인스턴스 자동 설정**: NAT Gateway 준비 후 도구 자동 설치 (AWS CLI, kubectl, eksctl, Docker)
- **ECR 지원**: Docker 이미지 push/pull을 위한 ECR 권한 및 헬퍼 스크립트 제공
- **CI/CD 파이프라인**: Jenkins + ArgoCD 기반 GitOps 배포 환경 구축
- **Jenkins ALB 연동**: Private Subnet의 Jenkins를 ALB를 통해 GitHub Webhook 수신
- **External Secrets**: AWS Secrets Manager + External Secrets Operator로 비밀 관리 자동화

---

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                    VPC (10.0.0.0/16)                        │
│                                                                             │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐         │
│  │      AZ: ap-northeast-2a     │  │      AZ: ap-northeast-2c     │         │
│  │                              │  │                              │         │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │         │
│  │  │ Public Subnet          │  │  │  │ Public Subnet          │  │         │
│  │  │ 10.0.10.0/24           │  │  │  │ 10.0.20.0/24           │  │         │
│  │  │  [Bastion] [NAT]       │  │  │  │  [NAT]                 │  │         │
│  │  │  [Jenkins ALB]         │  │  │  │  [Jenkins ALB]         │  │         │
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │         │
│  │                              │  │                              │         │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │         │
│  │  │ Private Mgmt Subnet    │  │  │  │ Private Mgmt Subnet    │  │         │
│  │  │ 10.0.50.0/24           │  │  │  │ 10.0.60.0/24           │  │         │ 
│  │  │  [Mgmt Instance]       │  │  │  │                        │  │         │
│  │  │  [Jenkins EC2]         │  │  │  │                        │  │         │
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │         │
│  │                              │  │                              │         │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │         │
│  │  │ Private EKS Subnet     │  │  │  │ Private EKS Subnet     │  │         │
│  │  │ 10.0.100.0/24          │  │  │  │ 10.0.110.0/24          │  │         │
│  │  │  [Worker Nodes]        │  │  │  │  [Worker Nodes]        │  │         │
│  │  │  [ArgoCD]              │  │  │  │                        │  │         │
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │         │
│  │                              │  │                              │         │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │         │
│  │  │ Private DB Subnet      │  │  │  │ Private DB Subnet      │  │         │
│  │  │ 10.0.150.0/24          │  │  │  │ 10.0.160.0/24          │  │         │
│  │  │  [RDS MySQL]           │  │  │  │                        │  │         │
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │         │
│  └──────────────────────────────┘  └──────────────────────────────┘         │
│                                                                             │
│                         ┌─────────────────────┐                             │
│                         │   EKS Control Plane │                             │
│                         │   (AWS Managed)     │                             │
│                         └─────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │          AWS Services               │
                    │  [ECR] [Secrets Manager] [IAM]      │
                    └─────────────────────────────────────┘
```

---

## 🔄 CI/CD 파이프라인

```
┌──────────┐     Webhook     ┌──────────┐     Push      ┌──────────┐
│  GitHub  │ ───────────────▶│  Jenkins │ ─────────────▶│   ECR    │
│  (App)   │                 │  (CI)    │               │          │
└──────────┘                 └────┬─────┘               └──────────┘
                                  │
                                  │ Update GitOps Repo
                                  ▼
┌──────────┐     Sync        ┌──────────┐     Get       ┌──────────┐
│  ArgoCD  │ ◀───────────────│  GitHub  │               │ Secrets  │
│  (CD)    │                 │ (GitOps) │               │ Manager  │
└────┬─────┘                 └──────────┘               └────┬─────┘
     │                                                       │
     │ Deploy                                                │
     ▼                                                       │
┌──────────────────────────────────────────────────────────┐ │
│   EKS                                                    │ │
│  ┌─────────────────┐    ┌─────────────────────────────┐  │ │
│  │  PetClinic Pods │◀───│ External Secrets Operator   │◀─┼─┘
│  │  (DB Secret)    │    │ (Sync Secrets)              │  │
│  └─────────────────┘    └─────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### CI/CD 흐름 설명

1. **개발자가 App Repository에 Push**
2. **GitHub Webhook → Jenkins ALB → Jenkins EC2**
3. **Jenkins가 빌드 및 테스트 수행**
4. **Docker 이미지 빌드 → ECR Push**
5. **Jenkins가 GitOps Repository 업데이트** (이미지 태그 변경)
6. **ArgoCD가 GitOps Repository 변경 감지**
7. **ArgoCD가 EKS에 새 버전 자동 배포**
8. **External Secrets Operator가 Secrets Manager에서 DB 정보 동기화**

---

## 📁 디렉토리 구조

```
project/
├── main.tf                    # 모듈 호출 및 aws-auth ConfigMap
├── variables.tf               # 루트 변수 정의
├── terraform.tfvars           # 변수 값 설정
├── providers.tf               # AWS, Kubernetes, Helm Provider 설정
├── version.tf                 # Terraform 버전 제약
├── data.tf                    # AMI 데이터 소스, AWS 계정 정보
├── keypair.tf                 # SSH 키페어
├── iam-mgmt.tf                # Mgmt 인스턴스 IAM 역할
├── iam-jenkins.tf             # Jenkins 인스턴스 IAM 역할
├── eks-addons.tf              # EKS Add-ons (ALB Controller, EFS CSI, External Secrets)
├── outputs.tf                 # 출력 값 정의
├── keys/                      # SSH 키 파일
└── modules/
    ├── network/               # VPC, Subnet, NAT Gateway, Route Table
    ├── ec2/                   # Bastion, Mgmt Instance
    ├── eks/                   # EKS Cluster, Node Group
    ├── db/                    # RDS MySQL
    ├── jenkins/               # Jenkins EC2, ALB, Security Group
    └── argocd/                # ArgoCD Helm Release
```

---

## 📦 생성되는 리소스

| 카테고리 | 리소스 |
|---------|--------|
| 네트워크 | VPC, Subnet(8개), NAT Gateway(2개), Internet Gateway, Route Table |
| 컴퓨팅 | Bastion Host, Management Instance, EKS Worker Nodes, Jenkins EC2 |
| 컨테이너 | EKS Cluster, Managed Node Group, Launch Template |
| 데이터베이스 | RDS MySQL |
| 보안 | Security Groups, IAM Roles, Key Pair |
| CI/CD | Jenkins EC2, Jenkins ALB, Target Group, ArgoCD (Helm) |
| 시크릿 관리 | AWS Secrets Manager Secret, External Secrets Operator (Helm) |
| EKS Add-ons | ALB Controller, EFS CSI Driver, External Secrets Operator |

---

## 🔗 모듈 의존성

```
Network Module ──┬──▶ NAT Gateway ──▶ EC2 Module (Mgmt)
                 │                          │
                 │                          ▼
                 │                   Jenkins Module
                 │
                 ├──▶ EKS Module ──┬──▶ ALB Controller ──▶ ArgoCD Module
                 │                 │
                 │                 ├──▶ EFS CSI Driver
                 │                 │
                 │                 └──▶ External Secrets Operator
                 │
                 └──▶ DB Module ──▶ Secrets Manager Secret
```

**핵심 의존성:**
- EC2 모듈은 NAT Gateway ID를 참조하여 NAT 준비 후 생성
- Jenkins 모듈은 Network, EC2 모듈 완료 후 생성
- ArgoCD 모듈은 EKS, ALB Controller 준비 후 설치
- External Secrets Operator는 EKS 준비 후 Helm으로 설치
- Secrets Manager Secret은 DB 모듈의 RDS 엔드포인트를 동적 참조
- Mgmt userdata는 네트워크 연결 확인 후 도구 설치 진행
- EKS ACTIVE 상태 확인 후 kubeconfig 자동 설정

---

## ⚙️ Mgmt 인스턴스 자동 설정

Mgmt 인스턴스 부팅 시 userdata 스크립트가 자동 실행됩니다:

1. **네트워크 연결 대기** - NAT Gateway 라우팅 전파 확인
2. **패키지 설치** - mysql-client, curl, unzip, jq
3. **Docker 설치** - Docker CE, Docker Compose 플러그인
4. **AWS CLI v2 설치**
5. **eksctl 설치**
6. **kubectl 설치**
7. **EKS 클러스터 대기** - ACTIVE 상태까지 대기
8. **kubeconfig 자동 설정**
9. **ECR 로그인 헬퍼 스크립트 생성** - `/usr/local/bin/ecr-login`

로그 확인:
```bash
sudo cat /var/log/userdata.log
```

---

## 🔧 Jenkins 설정

### Jenkins 자동 설치 항목

Jenkins EC2 부팅 시 자동 설치됩니다:
- Jenkins (LTS)
- Java 17 (Amazon Corretto)
- Docker
- AWS CLI v2
- kubectl
- Git

### Jenkins 접속

```bash
# Jenkins URL 확인
terraform output jenkins_url

# 브라우저에서 접속
http://<jenkins-alb-dns>
```

### 초기 비밀번호 확인

```bash
# Bastion 경유 Jenkins EC2 접속
ssh -i keys/test -J ubuntu@<bastion-ip> ec2-user@<jenkins-private-ip>

# 초기 비밀번호 확인
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 필수 플러그인

| 플러그인 | 용도 |
|----------|------|
| Git | Git 저장소 연동 |
| GitHub | GitHub Webhook 처리 |
| Pipeline | Jenkinsfile 기반 파이프라인 |
| Docker Pipeline | Docker 빌드 |
| Amazon ECR | ECR 로그인/Push |
| Kubernetes CLI | kubectl 명령 실행 |

### GitHub Webhook 설정

GitHub Repository → Settings → Webhooks → Add webhook:

| 항목 | 값 |
|------|-----|
| Payload URL | `http://<ALB_DNS>/github-webhook/` |
| Content type | `application/json` |
| Events | `Just the push event` |

---

## 🚀 ArgoCD 설정

### ArgoCD 접속

```bash
# Mgmt 인스턴스에서 Port Forward
kubectl port-forward svc/argocd-server -n argocd 8080:80

# 브라우저 접속 (로컬에서 SSH 터널링 사용)
# 또는 Mgmt에서 curl로 테스트
```

### ArgoCD 로그인 정보

```bash
# Admin 비밀번호 확인
terraform output -raw argocd_admin_password

# 로그인
Username: admin
Password: <위에서 확인한 비밀번호>
```

### ArgoCD CLI 사용

```bash
# ArgoCD CLI 설치 (Mgmt에서)
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# CLI 로그인
argocd login localhost:8080 --username admin --password <password> --insecure

# Repository 등록
argocd repo add https://github.com/<username>/<repo>.git \
  --username <github-username> \
  --password <github-token>

# Application 생성
argocd app create petclinic \
  --repo https://github.com/<username>/petclinic-gitops.git \
  --path overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

---

## 🔐 External Secrets 설정

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS                                            │
│  ┌─────────────────────┐                                                    │
│  │   Secrets Manager   │                                                    │
│  │  ┌───────────────┐  │                                                    │
│  │  │ petclinic/db  │  │◀───── Terraform이 생성                             │
│  │  │ - DB URL      │  │                                                    │
│  │  │ - Username    │  │                                                    │
│  │  │ - Password    │  │                                                    │
│  │  └───────────────┘  │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                               │
│             │ IRSA (IAM Role for Service Account)                           │
│             ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                          EKS Cluster                                │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │              External Secrets Operator                      │    │    │
│  │  │  (Terraform Helm으로 설치)                                   │    │    │
│  │  └──────────────────────────┬──────────────────────────────────┘    │    │
│  │                             │                                       │    │
│  │                             ▼                                       │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ ClusterSecretStore ──▶ ExternalSecret ──▶ K8s Secret        │    │    │
│  │  │ (GitOps에서 생성)      (GitOps에서 생성)  (자동 생성)         │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Terraform이 생성하는 리소스

| 리소스 | 설명 |
|--------|------|
| `aws_secretsmanager_secret` | DB 접속 정보 저장 |
| `aws_iam_policy` | Secrets Manager 읽기 권한 |
| `IRSA Role` | External Secrets SA에 연결 |
| `kubernetes_namespace` | external-secrets 네임스페이스 |
| `kubernetes_service_account` | IRSA 연결된 SA |
| `helm_release` | External Secrets Operator |

### GitOps에서 생성할 리소스 (petclinic-gitops)

⚠️ **중요**: ClusterSecretStore와 ExternalSecret은 Terraform이 아닌 GitOps repo에서 관리합니다.

**cluster-secret-store.yaml:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
```

**external-secret.yaml:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: petclinic-db-secret
  namespace: petclinic
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: petclinic-db-secret
    creationPolicy: Owner
  data:
    - secretKey: SPRING_DATASOURCE_URL
      remoteRef:
        key: petclinic-kr/db
        property: SPRING_DATASOURCE_URL
    - secretKey: SPRING_DATASOURCE_USERNAME
      remoteRef:
        key: petclinic-kr/db
        property: SPRING_DATASOURCE_USERNAME
    - secretKey: SPRING_DATASOURCE_PASSWORD
      remoteRef:
        key: petclinic-kr/db
        property: SPRING_DATASOURCE_PASSWORD
```

### 왜 이렇게 분리하나요?

| 구분 | Terraform | GitOps |
|------|-----------|--------|
| **적합한 리소스** | IAM, Secrets Manager, Helm | CRD 리소스 (ClusterSecretStore, ExternalSecret) |
| **이유** | CRD 캐싱 문제 없음 | ArgoCD로 쉽게 롤백/관리 |
| **변경 주기** | 낮음 (인프라 변경 시) | 높음 (설정 변경 시) |

### 상태 확인 명령어

```bash
# External Secrets Operator 상태
kubectl get pods -n external-secrets

# CRD 설치 확인
kubectl get crd | grep external-secrets

# ClusterSecretStore 상태 (GitOps 적용 후)
kubectl get clustersecretstore

# ExternalSecret 상태 (GitOps 적용 후)
kubectl get externalsecret -n petclinic

# 생성된 Secret 확인
kubectl get secret petclinic-db-secret -n petclinic -o yaml
```

---

## 🐳 ECR 사용 방법

Mgmt 인스턴스에서 ECR에 Docker 이미지를 push/pull 할 수 있습니다:

```bash
# ECR 로그인 (헬퍼 스크립트 사용)
ecr-login

# 또는 직접 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# ECR 리포지토리 생성
aws ecr create-repository \
  --repository-name my-app \
  --region ap-northeast-2

# 이미지 태그 및 푸시
docker build -t my-app .
docker tag my-app:latest \
  <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest
docker push \
  <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest
```

---

## 🚀 사용 방법

### 1. 사전 준비

```bash
# SSH 키 생성
ssh-keygen -t rsa -b 4096 -f keys/test -N ""

# AWS 자격증명 설정
aws configure
```

### 2. 배포

```bash
terraform init
terraform plan
terraform apply
```

### 3. 접속

```bash
# Bastion 접속
ssh -i keys/test ubuntu@<bastion_public_ip>

# Mgmt 접속 (Bastion 경유 - ProxyJump)
ssh -i keys/test -J ubuntu@<bastion_public_ip> ubuntu@<mgmt_private_ip>

# Jenkins 접속 (Bastion 경유)
ssh -i keys/test -J ubuntu@<bastion_public_ip> ec2-user@<jenkins_private_ip>

# kubectl 확인 (Mgmt에서 - 자동 설정됨)
kubectl get nodes

# ArgoCD 확인 (Mgmt에서)
kubectl get pods -n argocd
```

### 4. 주요 Output 확인

```bash
# 전체 접속 가이드
terraform output connection_guide

# Jenkins URL
terraform output jenkins_url

# GitHub Webhook URL
terraform output github_webhook_url

# ArgoCD 비밀번호
terraform output -raw argocd_admin_password
```

### 5. 삭제

```bash
terraform destroy
```

---

## 📋 Outputs 목록

| Output | 설명 |
|--------|------|
| `bastion_public_ip` | Bastion Host Public IP |
| `mgmt_private_ip` | Management Instance Private IP |
| `eks_cluster_name` | EKS 클러스터 이름 |
| `rds_address` | RDS 엔드포인트 |
| `jenkins_url` | Jenkins 접속 URL |
| `jenkins_private_ip` | Jenkins EC2 Private IP |
| `github_webhook_url` | GitHub Webhook 설정 URL |
| `argocd_namespace` | ArgoCD 네임스페이스 |
| `argocd_admin_password` | ArgoCD Admin 비밀번호 (sensitive) |
| `secrets_manager_secret_arn` | Secrets Manager Secret ARN |
| `secrets_manager_secret_name` | Secrets Manager Secret 이름 |
| `external_secrets_role_arn` | External Secrets IRSA Role ARN |
| `connection_guide` | 전체 접속 가이드 |

---

## 🔐 보안 고려사항

- **Jenkins**: Private Subnet 배치, ALB를 통해서만 접근 가능
- **ArgoCD**: EKS 내부 설치, Port Forward 또는 Ingress로 접근
- **RDS**: Private Subnet 배치, EKS/Mgmt에서만 접근 가능
- **Bastion**: SSH 22 포트만 허용 (운영 환경에서는 IP 제한 권장)
- **IAM**: 최소 권한 원칙 적용 (ECR, EKS 권한만 부여)
- **External Secrets**: IRSA로 Secrets Manager 접근 권한 부여 (Pod별 권한 분리)
- **Secrets Manager**: KMS 암호화, CloudTrail 감사 로그 자동 활성화

---

## 🛠️ 트러블슈팅

### ArgoCD 설치 실패 (ALB Controller Webhook 오류)

```bash
# 원인: ALB Controller가 준비되기 전에 ArgoCD 설치 시도
# 해결: terraform apply 재실행
terraform apply

# 또는 수동으로 ArgoCD 재설치
helm uninstall argocd -n argocd
kubectl delete namespace argocd
terraform apply
```

### Jenkins 접속 불가

```bash
# ALB Health Check 확인
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Jenkins 서비스 상태 확인 (Jenkins EC2에서)
sudo systemctl status jenkins
sudo cat /var/log/user-data.log
```

### kubectl 명령 실패 (Mgmt에서)

```bash
# kubeconfig 수동 설정
aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2

# 클러스터 상태 확인
aws eks describe-cluster --name <cluster-name> --query 'cluster.status'
```