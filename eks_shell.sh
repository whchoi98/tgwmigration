#!/bin/bash
# command ./eks_shell.sh
# eks version is input from shell prompt
# EKS 버전은 셸 프롬프트에서 입력받습니다.

cd ~/environment/
# Change directory to ~/environment
# 작업 디렉토리를 ~/environment로 변경

echo "--------------------------"
echo "Export - VPC ID, SubnetID, CIDR, Subnet name"
# VPC ID, Subnet ID, CIDR, Subnet 이름을 환경 변수로 설정
echo "--------------------------"

# Define subnet and VPC names / 서브넷 및 VPC 이름 정의
export PublicSubnetA_NAME=DMZVPC-PublicSubnetA
export PublicSubnetB_NAME=DMZVPC-PublicSubnetB
export PrivateSubnetA_NAME=DMZVPC-PrivateSubnetA
export PrivateSubnetB_NAME=DMZVPC-PrivateSubnetB
export VPC_NAME="DMZVPC"

# Retrieve the VPC ID / VPC ID 조회
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" | jq -r '.Vpcs[].VpcId')

# Retrieve the Subnet IDs / Subnet ID 조회
export PublicSubnetA=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PublicSubnetA_NAME" | jq -r '.Subnets[].SubnetId')
export PublicSubnetB=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PublicSubnetB_NAME" | jq -r '.Subnets[].SubnetId')
export PrivateSubnetA=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PrivateSubnetA_NAME" | jq -r '.Subnets[].SubnetId')
export PrivateSubnetB=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PrivateSubnetB_NAME" | jq -r '.Subnets[].SubnetId')

# Save variables to bash_profile / 환경 변수를 bash_profile에 저장
echo "export VPC_ID=${VPC_ID}" | tee -a ~/.bash_profile
echo "export PublicSubnetA=${PublicSubnetA}" | tee -a ~/.bash_profile
echo "export PublicSubnetB=${PublicSubnetB}" | tee -a ~/.bash_profile
echo "export PrivateSubnetA=${PrivateSubnetA}" | tee -a ~/.bash_profile
echo "export PrivateSubnetB=${PrivateSubnetB}" | tee -a ~/.bash_profile

# EKS 클러스터 환경변수 생성 / Create environment variables for EKS Cluster
echo "--------------------------"
echo "Create environment variables for creating EKS Cluster."
echo "--------------------------"

# Prompt user for EKS version / 사용자에게 EKS 버전을 입력받음
read -p "Enter the EKS version (e.g., 1.29): " USER_EKS_VERSION

# Set default value if no input / 입력이 없을 경우 기본값 설정
if [ -z "$USER_EKS_VERSION" ]; then
  USER_EKS_VERSION="1.29"  # Default EKS version / 기본 EKS 버전
  echo "No version entered. Defaulting to $USER_EKS_VERSION."
fi

# Define EKS-related variables / EKS 관련 환경 변수 설정
export EKSCLUSTER_NAME="DMZVPC"
export EKS_VERSION="$USER_EKS_VERSION"
export INSTANCE_TYPE="m6i.xlarge"
export PUBLIC_MGMD_NODE="managed-frontend-workloads"
export PRIVATE_MGMD_NODE="managed-backend-workloads"

# Save variables to bash_profile / 환경 변수를 bash_profile에 저장
echo "export EKSCLUSTER_NAME=${EKSCLUSTER_NAME}" | tee -a ~/.bash_profile
echo "export EKS_VERSION=${EKS_VERSION}" | tee -a ~/.bash_profile
echo "export INSTANCE_TYPE=${INSTANCE_TYPE}" | tee -a ~/.bash_profile
echo "export PUBLIC_MGMD_NODE=${PUBLIC_MGMD_NODE}" | tee -a ~/.bash_profile
echo "export PRIVATE_MGMD_NODE=${PRIVATE_MGMD_NODE}" | tee -a ~/.bash_profile

# Apply changes to the current shell / 현재 셸에 변경사항 적용
source ~/.bash_profile

echo "--------------------------"
echo "Environment variables for EKS Cluster creation have been created in bash_profile."
# EKS 클러스터 생성용 환경 변수가 bash_profile에 생성되었습니다.
echo "--------------------------"
