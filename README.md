# Terraform Infra 자동화 구축

Infra를 Terraform으로 프로비저닝하는 Infrastructure as Code(IaC) 프로젝트입니다

## ✨ 주요 특징

- **모듈화된 구조**: Network, EC2, EKS, DB 모듈로 분리
- **Multi-AZ 구성**: 2개 가용영역(ap-northeast-2a, ap-northeast-2c) 배포
- **보안 강화**: Private Subnet에 워커 노드 배치, Bastion Host를 통한 접근
- **Ubuntu 24.04 기반**: EKS 워커 노드에 Ubuntu 24.04 LTS 사용
- **자동화**: aws-auth ConfigMap 자동 구성, kubeconfig 자동 설정
- **Mgmt 인스턴스 자동 설정**: NAT Gateway 준비 후 도구 자동 설치 (AWS CLI, kubectl, eksctl, Docker)
- **ECR 지원**: Docker 이미지 push/pull을 위한 ECR 권한 및 헬퍼 스크립트 제공

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
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │         │
│  │                              │  │                              │         │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │         │
│  │  │ Private Mgmt Subnet    │  │  │  │ Private Mgmt Subnet    │  │         │
│  │  │ 10.0.50.0/24           │  │  │  │ 10.0.60.0/24           │  │         │ 
│  │  │  [Mgmt Instance]       │  │  │  │                        │  │         │
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │         │
│  │                              │  │                              │         │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │         │
│  │  │ Private EKS Subnet     │  │  │  │ Private EKS Subnet     │  │         │
│  │  │ 10.0.100.0/24          │  │  │  │ 10.0.110.0/24          │  │         │
│  │  │  [Worker Nodes]        │  │  │  │  [Worker Nodes]        │  │         │
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
```

---

## 📁 디렉토리 구조

```
project/
├── main.tf                    # 모듈 호출 및 aws-auth ConfigMap
├── variables.tf               # 루트 변수 정의
├── terraform.tfvars           # 변수 값 설정
├── providers.tf               # AWS, Kubernetes, Helm Provider 설정
├── version.tf                 # Terraform 버전 제약
├── data.tf                    # AMI 데이터 소스
├── keypair.tf                 # SSH 키페어
├── iam-mgmt.tf                # Mgmt 인스턴스 IAM 역할
├── eks-addons.tf              # EKS Add-ons (ALB Controller, EFS CSI)
├── keys/                      # SSH 키 파일
└── modules/
    ├── network/               # VPC, Subnet, NAT Gateway, Route Table
    ├── ec2/                   # Bastion, Mgmt Instance
    ├── eks/                   # EKS Cluster, Node Group
    └── db/                    # RDS MySQL
```

---

## 📦 생성되는 리소스

| 카테고리 | 리소스 |
|---------|--------|
| 네트워크 | VPC, Subnet(8개), NAT Gateway(2개), Internet Gateway, Route Table |
| 컴퓨팅 | Bastion Host, Management Instance, EKS Worker Nodes |
| 컨테이너 | EKS Cluster, Managed Node Group, Launch Template |
| 데이터베이스 | RDS MySQL |
| 보안 | Security Groups, IAM Roles, Key Pair |

---

## 🔗 모듈 의존성

```
Network Module ──┬──▶ NAT Gateway ──▶ EC2 Module (Mgmt)
                 │
                 ├──▶ EKS Module ──▶ aws-auth ConfigMap
                 │
                 └──▶ DB Module
```

**핵심 의존성:**
- EC2 모듈은 NAT Gateway ID를 참조하여 NAT 준비 후 생성
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

# kubectl 확인 (Mgmt에서 - 자동 설정됨)
kubectl get nodes
```

### 4. 삭제

```bash
terraform destroy
```