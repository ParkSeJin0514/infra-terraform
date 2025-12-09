# ============================================================================
# iam-mgmt.tf - Management 인스턴스 IAM 설정
# ============================================================================
# Mgmt EC2 인스턴스가 EKS 클러스터를 관리하기 위한 IAM Role과 Policy
#
# 이 역할은 aws-auth ConfigMap에 등록되어 kubectl 권한을 얻습니다.
# ============================================================================

# ============================================================================
# IAM Role
# ============================================================================
# EC2 서비스가 이 역할을 사용할 수 있도록 Trust Policy 설정
# ============================================================================
resource "aws_iam_role" "mgmt" {
  name = "${var.project_name}-mgmt-role"

  # Trust Policy: 누가 이 역할을 assume할 수 있는지
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-mgmt-role"
    Project     = var.project_name
    Environment = "dev"
  }
}

# ============================================================================
# EKS 전체 권한 (실습/관리용)
# ============================================================================
# eks:* 권한으로 클러스터 관리 작업 수행 가능
# - eks:DescribeCluster (kubeconfig 생성)
# - eks:ListClusters
# - eks:AccessKubernetesApi
# ============================================================================
resource "aws_iam_policy" "mgmt_eks_full" {
  name        = "${var.project_name}-mgmt-eks-full"
  description = "Full EKS permissions for mgmt EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mgmt_eks_full_attach" {
  role       = aws_iam_role.mgmt.name
  policy_arn = aws_iam_policy.mgmt_eks_full.arn
}

# ============================================================================
# AWS 관리형 정책 연결
# ============================================================================

# Administrator 전체 권한 - 모든 AWS 서비스 및 리소스에 대한 전체 액세스
resource "aws_iam_role_policy_attachment" "mgmt_admin" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# EFS 접근 권한 - EFS CSI Driver 설정, 마운트 테스트 등
resource "aws_iam_role_policy_attachment" "mgmt_efs" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
}

# EC2 읽기 권한 - 인스턴스 상태 조회, 디버깅 등
resource "aws_iam_role_policy_attachment" "mgmt_ec2_readonly" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# ECR 전체 권한 - Docker 이미지 push/pull
resource "aws_iam_role_policy_attachment" "mgmt_ecr_full" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# ============================================================================
# Instance Profile
# ============================================================================
# IAM Role을 EC2 인스턴스에 연결하기 위한 컨테이너
# EC2 인스턴스는 직접 IAM Role을 사용할 수 없고,
# Instance Profile을 통해 간접적으로 역할을 부여받습니다.
# ============================================================================
resource "aws_iam_instance_profile" "mgmt" {
  name = "${var.project_name}-mgmt-instance-profile"
  role = aws_iam_role.mgmt.name
}