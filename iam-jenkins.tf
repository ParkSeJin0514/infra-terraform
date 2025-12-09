# ============================================================================
# iam-jenkins.tf - Jenkins EC2용 IAM Role
# ============================================================================
# Jenkins가 ECR Push, EKS 접근 등을 수행하기 위한 IAM 역할
# ============================================================================

# ----------------------------------------------------------------------------
# IAM Role
# ----------------------------------------------------------------------------
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-jenkins-role"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ----------------------------------------------------------------------------
# IAM Instance Profile
# ----------------------------------------------------------------------------
resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name

  tags = {
    Name      = "${var.project_name}-jenkins-profile"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ----------------------------------------------------------------------------
# ECR 권한 - Docker 이미지 Push/Pull
# ----------------------------------------------------------------------------
resource "aws_iam_role_policy" "jenkins_ecr" {
  name = "${var.project_name}-jenkins-ecr-policy"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

# ----------------------------------------------------------------------------
# EKS 권한 - 클러스터 정보 조회 및 kubeconfig 설정
# ----------------------------------------------------------------------------
resource "aws_iam_role_policy" "jenkins_eks" {
  name = "${var.project_name}-jenkins-eks-policy"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# ----------------------------------------------------------------------------
# SSM 권한 (선택사항) - Session Manager 접근용
# ----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
