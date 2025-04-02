#!/bin/bash

AWS_REGION="ap-northeast-2"

# 현재 계정 정보 출력
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ACCOUNT_ALIAS=$(aws iam list-account-aliases --query "AccountAliases[0]" --output text 2>/dev/null)
echo "🧾 현재 AWS 계정 정보"
echo "Account ID    : $ACCOUNT_ID"
echo "Account Alias : ${ACCOUNT_ALIAS:-(Alias 없음)}"
echo "Region        : $AWS_REGION"
echo ""

# VPC 목록 가져오기
VPC_LIST=$(aws ec2 describe-vpcs --region $AWS_REGION --output json)
VPC_COUNT=$(echo "$VPC_LIST" | jq '.Vpcs | length')

# VPC 리스트 넘버링하여 출력
echo "📋 VPC 리스트:"
printf "%-3s  %-20s  %-20s  %s\n" "No" "VPC ID" "Name" "CIDR Block"
echo "---------------------------------------------------------------"
for i in $(seq 0 $(($VPC_COUNT - 1))); do
  VPC_ID=$(echo "$VPC_LIST" | jq -r ".Vpcs[$i].VpcId")
  VPC_CIDR=$(echo "$VPC_LIST" | jq -r ".Vpcs[$i].CidrBlock")
  VPC_NAME=$(echo "$VPC_LIST" | jq -r ".Vpcs[$i].Tags // [] | map(select(.Key==\"Name\"))[0].Value // \"-\"")
  printf "%-3s  %-20s  %-20s  %s\n" "$i" "$VPC_ID" "$VPC_NAME" "$VPC_CIDR"
done
echo "---------------------------------------------------------------"

# 사용자 입력 받기
read -p "✅ 조회할 VPC (번호 / VPC ID / VPC Name): " SELECT

# VPC ID 확인 로직
if [[ "$SELECT" =~ ^[0-9]+$ ]]; then
  if (( SELECT >= 0 && SELECT < VPC_COUNT )); then
    VPC_ID=$(echo "$VPC_LIST" | jq -r ".Vpcs[$SELECT].VpcId")
  else
    echo "❌ 잘못된 번호입니다."
    exit 1
  fi
elif [[ "$SELECT" =~ ^vpc- ]]; then
  VPC_ID="$SELECT"
else
  VPC_ID=$(echo "$VPC_LIST" | jq -r --arg name "$SELECT" '.Vpcs[] | select((.Tags // []) | map(select(.Key=="Name" and .Value==$name)) | length > 0) | .VpcId')
  if [[ -z "$VPC_ID" ]]; then
    echo "❌ 입력한 이름으로 VPC를 찾을 수 없습니다."
    exit 1
  fi
fi

echo ""
echo "🔍 선택된 VPC ID: $VPC_ID"
echo ""

# 💡 리소스 ID로 Name 태그 가져오는 함수
get_resource_name() {
  local resource_id=$1
  local name="-"

  if [[ $resource_id == igw-* ]]; then
    name=$(aws ec2 describe-internet-gateways --internet-gateway-ids $resource_id \
      --region $AWS_REGION --query 'InternetGateways[0].Tags[?Key==`Name`].Value | [0]' --output text 2>/dev/null)
  elif [[ $resource_id == tgw-* ]]; then
    name=$(aws ec2 describe-transit-gateways --transit-gateway-ids $resource_id \
      --region $AWS_REGION --query 'TransitGateways[0].Tags[?Key==`Name`].Value | [0]' --output text 2>/dev/null)
  elif [[ $resource_id == vpce-* ]]; then
    name=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $resource_id \
      --region $AWS_REGION --query 'VpcEndpoints[0].Tags[?Key==`Name`].Value | [0]' --output text 2>/dev/null)
  elif [[ $resource_id == eni-* ]]; then
    name=$(aws ec2 describe-network-interfaces --network-interface-ids $resource_id \
      --region $AWS_REGION --query 'NetworkInterfaces[0].TagSet[?Key==`Name`].Value | [0]' --output text 2>/dev/null)
  elif [[ $resource_id == nat-* ]]; then
    name=$(aws ec2 describe-nat-gateways --nat-gateway-ids $resource_id \
      --region $AWS_REGION --query 'NatGateways[0].Tags[?Key==`Name`].Value | [0]' --output text 2>/dev/null)
  fi

  echo "${name:--}"
}

# 라우팅 테이블 조회
ROUTE_TABLES=$(aws ec2 describe-route-tables \
  --region $AWS_REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --output json)

echo "📦 라우팅 테이블 상세:"
echo ""

echo "$ROUTE_TABLES" | jq -c '.RouteTables[]' | while read -r route_table; do
  RT_ID=$(echo "$route_table" | jq -r '.RouteTableId')
  RT_NAME=$(echo "$route_table" | jq -r '.Tags // [] | map(select(.Key == "Name"))[0].Value // "-"')

  echo "📦 라우팅 테이블: $RT_ID  (Name: $RT_NAME)"
  echo "---------------------------------------------------------------------------------------------"
  printf "%-22s %-22s %-30s %-10s %-10s\n" "Destination" "Target" "TargetName" "State" "Propagated"
  echo "---------------------------------------------------------------------------------------------"

  echo "$route_table" | jq -r '
    .Routes[] |
    [
      (.DestinationCidrBlock // .DestinationPrefixListId),
      (.GatewayId // .NatGatewayId // .TransitGatewayId // .VpcPeeringConnectionId // .InstanceId // .LocalGatewayId // .NetworkInterfaceId // .EgressOnlyInternetGatewayId // "-"),
      .State,
      (if has("Propagated") then (.Propagated|tostring) else "false" end)
    ] | @tsv' |
  while IFS=$'\t' read -r destination target state propagated; do
    target_name=$(get_resource_name "$target")
    printf "%-22s %-22s %-30s %-10s %-10s\n" "$destination" "$target" "$target_name" "$state" "$propagated"
  done

  echo ""
done
