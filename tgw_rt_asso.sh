#!/bin/bash

# 1. Transit Gateway Route Table 목록 조회
echo "📌 Available Transit Gateway Route Tables:"
aws ec2 describe-transit-gateway-route-tables \
  --query "TransitGatewayRouteTables[*].{Name:Tags[?Key=='Name']|[0].Value,Id:TransitGatewayRouteTableId}" \
  --output table

read -p "📝 Enter Transit Gateway Route Table ID to associate with: " TGW_RT_ID

# 2. Transit Gateway Attachment 목록 출력
echo -e "\n📎 Available Transit Gateway Attachments:"
aws ec2 describe-transit-gateway-attachments \
  --query "TransitGatewayAttachments[*].{Id:TransitGatewayAttachmentId,Name:Tags[?Key=='Name']|[0].Value,ResourceType:ResourceType,State:State}" \
  --output table

read -p "📝 Enter Transit Gateway Attachment ID to associate: " ATTACHMENT_ID

# 3. 사용자 확인
read -p "⚠️ Associate $ATTACHMENT_ID with $TGW_RT_ID? (yes/no): " CONFIRM

if [[ "$CONFIRM" == "yes" ]]; then
  echo "🚀 Associating..."
  aws ec2 associate-transit-gateway-route-table \
    --transit-gateway-route-table-id "$TGW_RT_ID" \
    --transit-gateway-attachment-id "$ATTACHMENT_ID"
  echo "✅ Successfully associated $ATTACHMENT_ID with $TGW_RT_ID"
else
  echo "🚫 Cancelled"
fi
