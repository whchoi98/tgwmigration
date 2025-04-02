#!/bin/bash

AWS_REGION="ap-northeast-2"

# 현재 계정 정보 출력
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ACCOUNT_ALIAS=$(aws iam list-account-aliases --query "AccountAliases[0]" --output text 2>/dev/null)

echo "🧾 AWS 계정 정보"
echo "Account ID    : $ACCOUNT_ID"
echo "Account Alias : ${ACCOUNT_ALIAS:-(Alias 없음)}"
echo "Region        : $AWS_REGION"
echo ""

# TGW Route Tables 조회
echo "📋 Transit Gateway Route Tables:"
TGW_ROUTE_TABLES=$(aws ec2 describe-transit-gateway-route-tables --region $AWS_REGION)
TGW_ROUTE_TABLE_IDS=($(echo "$TGW_ROUTE_TABLES" | jq -r '.TransitGatewayRouteTables[].TransitGatewayRouteTableId'))

for i in "${!TGW_ROUTE_TABLE_IDS[@]}"; do
  TGW_RT_ID="${TGW_ROUTE_TABLE_IDS[$i]}"
  NAME=$(echo "$TGW_ROUTE_TABLES" | jq -r ".TransitGatewayRouteTables[$i].Tags[]? | select(.Key==\"Name\") | .Value")
  NAME=${NAME:--}
  echo "$i. $TGW_RT_ID (Name: $NAME)"
done

echo ""
read -p "✅ 조회할 TGW Route Table 번호 또는 ID 입력: " SELECT

if [[ "$SELECT" =~ ^[0-9]+$ ]]; then
  if (( SELECT >= 0 && SELECT < ${#TGW_ROUTE_TABLE_IDS[@]} )); then
    TGW_RT_ID="${TGW_ROUTE_TABLE_IDS[$SELECT]}"
  else
    echo "❌ 잘못된 번호입니다."
    exit 1
  fi
else
  TGW_RT_ID="$SELECT"
fi

echo ""
echo "🔍 선택된 TGW Route Table ID: $TGW_RT_ID"
echo ""

# 라우팅 정보 조회
ROUTES=$(aws ec2 search-transit-gateway-routes \
  --region $AWS_REGION \
  --transit-gateway-route-table-id "$TGW_RT_ID" \
  --filters Name=type,Values=static,propagated \
  --output json)

ROUTE_COUNT=$(echo "$ROUTES" | jq '.Routes | length')
if [ "$ROUTE_COUNT" -eq 0 ]; then
  echo "⚠️  라우팅 정보가 없습니다."
  exit 0
fi

# TGW Attachment → Name 매핑 테이블 생성
declare -A ATTACH_NAME_MAP
ALL_ATTACHMENTS=$(aws ec2 describe-transit-gateway-attachments --region $AWS_REGION)

for row in $(echo "$ALL_ATTACHMENTS" | jq -c '.TransitGatewayAttachments[]'); do
  ATTACH_ID=$(echo "$row" | jq -r '.TransitGatewayAttachmentId')
  ATTACH_NAME=$(echo "$row" | jq -r '.Tags[]? | select(.Key=="Name") | .Value' 2>/dev/null)
  ATTACH_NAME=${ATTACH_NAME:--}
  ATTACH_NAME_MAP["$ATTACH_ID"]="$ATTACH_NAME"
done

echo "📦 라우팅 정보:"
printf "%-22s %-24s %-36s %-19s %-10s\n" "Destination" "AttachmentId" "Target Name" "Type" "State"
echo "----------------------------------------------------------------------------------------------------------------------------------"

echo "$ROUTES" | jq -r '
  .Routes[] | 
  [.DestinationCidrBlock, (.TransitGatewayAttachments[0].TransitGatewayAttachmentId // "-"), .Type, .State] | @tsv' |
while IFS=$'\t' read -r dst attach_id type state; do
  attach_name=${ATTACH_NAME_MAP["$attach_id"]}
  printf "%-22s %-24s %-36s %-19s %-10s\n" "$dst" "$attach_id" "$attach_name" "$type" "$state"
done
