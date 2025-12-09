# ============================================================================
# main.tf - 모듈 호출 및 aws-auth ConfigMap 설정
# ============================================================================
# 이 파일은 프로젝트의 핵심 오케스트레이션 파일입니다.
# 3개의 모듈(network, ec2, eks)을 호출하고, aws-auth ConfigMap을 자동 설정합니다.
# ============================================================================

# ============================================================================
# Network 모듈
# ============================================================================
# VPC, Subnet, NAT Gateway, Route Table 등 네트워크 인프라 생성
# 다른 모든 모듈이 이 모듈의 출력값(vpc_id, subnet_id)을 참조합니다.
# ============================================================================
module "network" {
  source = "./modules/network"

  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  project_name = var.project_name
}

# ============================================================================
# EC2 모듈
# ============================================================================
# Bastion Host와 Management Instance 생성
# - Bastion: Public Subnet에 배치, 외부에서 SSH 접근 가능
# - Mgmt: Private Subnet에 배치, kubectl/eksctl 도구 자동 설치
# ============================================================================
module "ec2" {
  source = "./modules/ec2"

  # 공통 정보
  project_name = var.project_name
  vpc_id       = module.network.vpc_id # Network 모듈 출력값 참조
  ami          = var.ami
  key_name     = var.key_name

  # Bastion 설정 - Public Subnet에 배치
  bastion_instance_type = var.bastion_instance_type
  public_subnet_id      = module.network.public_subnet_id[0]

  # Mgmt 설정 - Private Subnet에 배치
  mgmt_instance_type = var.mgmt_instance_type
  private_subnet_id  = module.network.private_mgmt_subnet_id[0]

  # IAM Instance Profile - EKS 관리 권한 부여
  mgmt_iam_instance_profile = aws_iam_instance_profile.mgmt.name

  # kubeconfig 자동 설정용 - region과 클러스터 이름
  region       = var.region
  cluster_name = "${var.project_name}-eks"

  # NAT Gateway 생성 완료 후 EC2 생성 (Mgmt 인스턴스의 인터넷 접근 보장)
  nat_gateway_ids = module.network.nat_gateway_ids
}

# ============================================================================
# EKS 모듈
# ============================================================================
# EKS 클러스터와 Managed Node Group 생성
# - Control Plane: Public + Private Subnet 모두 접근 가능
# - Worker Node: Private Subnet에만 배치 (보안)
# ============================================================================
module "eks" {
  source = "./modules/eks"

  # 클러스터 기본 설정
  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.eks_version
  vpc_id          = module.network.vpc_id

  # Control Plane 서브넷 (Public + Private)
  # concat()으로 두 리스트를 합쳐서 전달
  # EKS Control Plane은 여러 AZ에 배포되며, Public/Private 모두 접근 가능
  control_plane_subnet_ids = concat(
    module.network.public_subnet_id,
    module.network.private_eks_subnet_id
  )

  # Worker Node는 Private EKS Subnet에만 배치 (보안 강화)
  worker_subnet_ids = module.network.private_eks_subnet_id

  # API Server 엔드포인트 접근 설정
  endpoint_private_access = true # VPC 내부에서 접근 가능
  endpoint_public_access  = true # 인터넷에서도 접근 가능

  # Control Plane 로깅 (CloudWatch Logs로 전송)
  cluster_log_types = var.eks_cluster_log_types

  # Node Group 설정
  node_group_name = "${var.project_name}-workers"
  instance_types  = var.eks_instance_types
  capacity_type   = var.eks_capacity_type # ON_DEMAND 또는 SPOT

  # 디스크 및 스케일링 설정
  disk_size    = var.eks_disk_size
  desired_size = var.eks_desired_size
  max_size     = var.eks_max_size
  min_size     = var.eks_min_size

  # 롤링 업데이트 시 동시에 중단될 수 있는 노드 비율 (33% = 1/3)
  max_unavailable_percentage = var.eks_max_unavailable_percentage

  # SSH 접근용 키페어
  key_name = var.key_name

  # Management Instance Security Group 연결
  # enable_mgmt_sg_rule: Boolean으로 조건부 생성 (Plan 시점 에러 방지)
  # mgmt_security_group_id: Mgmt → EKS API 접근 허용 규칙 생성에 사용
  enable_mgmt_sg_rule    = true
  mgmt_security_group_id = module.ec2.mgmt_security_group_id

  # Kubernetes 노드 레이블
  # merge()로 기본 레이블과 사용자 정의 레이블 병합
  node_labels = merge(
    {
      Environment = "production"
      Application = var.project_name
      ManagedBy   = "terraform"
    },
    var.eks_node_labels
  )

  # Kubernetes 노드 Taint (선택사항)
  node_taints = var.eks_node_taints

  # kubelet 추가 옵션 (예: --max-pods=110)
  kubelet_extra_args = var.eks_kubelet_extra_args

  # 리소스 태그
  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terraform"
  }

  # Network 모듈 완료 후 EKS 생성
  depends_on = [
    module.network
  ]
}

# ============================================================================
# RDS 모듈
# ============================================================================
# MySQL RDS 인스턴스 생성
# - Private DB Subnet에 배치 (인터넷에서 접근 불가)
# - EKS Worker Node에서만 접근 가능하도록 Security Group 설정
# ============================================================================
module "db" {
  source = "./modules/db"

  # 기본 식별 정보
  identifier = "${var.project_name}-db"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_db_subnet_id

  # 엔진 설정
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  parameter_group_family = var.db_parameter_group_family

  # 인스턴스 사양
  instance_class = var.db_instance_class

  # 스토리지 설정
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = var.db_storage_type
  storage_encrypted     = var.db_storage_encrypted

  # 데이터베이스 설정
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  # 네트워크 설정
  publicly_accessible = false # 항상 비공개
  multi_az            = var.db_multi_az

  # 접근 허용 - EKS Worker Node와 Management Instance에서 접근
  allowed_security_group_ids = [
    module.eks.node_security_group_id,
    module.ec2.mgmt_security_group_id
  ]

  # 삭제 관련 설정
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.project_name}-mysql-final"

  # 태그
  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terraform"
  }

  # Network와 EKS 모듈 완료 후 생성
  depends_on = [
    module.network,
    module.eks
  ]
}

# ============================================================================
# Jenkins 모듈
# ============================================================================
# CI/CD 파이프라인용 Jenkins 서버
# - Private Subnet에 배치 (보안)
# - ALB를 통해 GitHub Webhook 수신
# - Docker, kubectl 등 CI/CD 도구 자동 설치
# ============================================================================
module "jenkins" {
  source = "./modules/jenkins"

  # 기본 설정
  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  region       = var.region

  # EC2 설정
  ami               = var.ami
  instance_type     = var.jenkins_instance_type
  key_name          = var.key_name
  private_subnet_id = module.network.private_mgmt_subnet_id[0]
  root_volume_size  = 30

  # ALB 설정 (2개 이상 AZ의 Public Subnet 필요)
  public_subnet_ids = module.network.public_subnet_id

  # Security Group - Bastion에서 SSH 접근 허용
  bastion_security_group_id = module.ec2.bastion_security_group_id

  # IAM - ECR Push, EKS 접근 권한
  iam_instance_profile = aws_iam_instance_profile.jenkins.name

  # HTTPS (선택사항 - ACM 인증서가 있는 경우)
  # alb_certificate_arn = aws_acm_certificate.jenkins.arn

  # NAT Gateway 의존성 (Private Subnet에서 인터넷 접근 보장)
  nat_gateway_ids = module.network.nat_gateway_ids

  # 태그
  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terraform"
  }

  # 의존성: Network, EC2 모듈 완료 후 생성
  depends_on = [
    module.network,
    module.ec2
  ]
}

# ============================================================================
# ArgoCD 모듈
# ============================================================================
# GitOps 기반 Continuous Delivery 도구
# - EKS 클러스터 내부에 설치
# - GitOps Repository를 감시하고 자동 배포
# - Helm Chart로 설치
# ============================================================================
module "argocd" {
  source = "./modules/argocd"

  # 기본 설정
  project_name = var.project_name
  namespace    = "argocd"

  # Helm Chart 버전
  chart_version = var.argocd_chart_version

  # Server 설정
  server_service_type = "ClusterIP"
  server_replicas     = 1
  insecure            = true

  # Ingress 설정 (ALB)
  server_ingress_enabled = true
  server_ingress_class   = "alb"

  # GitOps Application 설정
  app_name               = "petclinic"
  app_namespace          = "petclinic"
  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = "main"
  gitops_path            = "."

  # 태그
  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terraform"
  }

  depends_on = [
    module.eks,
    helm_release.alb_controller
  ]
}

# ============================================================================
# AWS Auth ConfigMap (자동화)
# ============================================================================
# EKS 클러스터의 인증/인가를 관리하는 ConfigMap
# 이 ConfigMap에 IAM Role을 등록해야 해당 역할로 클러스터에 접근 가능
#
# mapRoles에 등록되는 역할:
# 1. Node IAM Role: 워커 노드가 클러스터에 조인
# 2. Mgmt IAM Role: Management 인스턴스에서 kubectl 사용
# ============================================================================
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      # 워커 노드 IAM Role 등록
      # system:bootstrappers, system:nodes 그룹으로 노드가 클러스터에 조인
      {
        rolearn  = module.eks.node_iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      # Mgmt IAM Role 등록
      # system:masters 그룹으로 클러스터 관리자 권한 부여
      {
        rolearn  = aws_iam_role.mgmt.arn
        username = "mgmt-admin"
        groups   = ["system:masters"]
      }
    ])
  }

  # 기존 ConfigMap 내용을 덮어쓰기
  force = true

  # EKS 클러스터 생성 완료 후 실행
  depends_on = [module.eks]
}