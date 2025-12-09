# ============================================================================
# keypair.tf - SSH Key Pair
# ============================================================================
# EC2 인스턴스 SSH 접근을 위한 Key Pair 생성
#
# 사용법:
#   1. 로컬에서 SSH 키 생성: ssh-keygen -t rsa -b 4096 -f keys/test
#   2. terraform apply 시 Public Key가 AWS에 등록됨
#   3. SSH 접속: ssh -i keys/test ubuntu@<ip>
# ============================================================================
resource "aws_key_pair" "test" {
  key_name = var.key_name # AWS에 등록될 Key Pair 이름

  # file() 함수로 로컬 파일에서 Public Key 읽기
  # path.module: 현재 모듈(루트)의 파일 시스템 경로
  public_key = file("${path.module}/keys/test.pub")
}