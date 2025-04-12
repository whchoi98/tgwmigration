#!/bin/bash

# 1. Transit Gateway Route Table 목록 조회 및 선택
echo "📌 Transit Gateway Route Tables:"
aws ec2 describe-transit-gateway-route-tables \
  --query "TransitGatewayRouteTables[*].{Name:Tags[?Key=='Name']|[0].Value,Id:TransitGatewayRouteTableId}" \
  --output table

read -p "📝 Enter Transit Gateway Route Table ID: " TGW_RT_ID

# 2. 선택한 Route Table에 연결된 Associations 출력
echo -e "\n🔍 Associations in Route Table $TGW_RT_ID:"
aws ec2 get-transit-gateway-route-table-associations \
  --transit-gateway-route-table-id "$TGW_RT_ID" \
  --query "Associations[*].{AttachmentId:TransitGatewayAttachmentId,ResourceId:ResourceId,ResourceType:ResourceType,State:State}" \
  --output table

# 3. 연결된 Attachment 목록에서 이름 포함하여 출력
echo -e "\n🔍 Getting Attachment Names..."
ASSOCIATIONS=$(aws ec2 get-transit-gateway-route-table-associations \
  --transit-gateway-route-table-id "$TGW_RT_ID" \
  --query "Associations[*].TransitGatewayAttachmentId" \
  --output text)

echo -e "\n📎 Attachment Info:"
for ATTACH_ID in $ASSOCIATIONS; do
  NAME=$(aws ec2 describe-transit-gateway-attachments \
    --transit-gateway-attachment-ids "$ATTACH_ID" \
    --query "TransitGatewayAttachments[0].Tags[?Key=='Name'].[Value]" \
    --output text)
  echo "$ATTACH_ID - ${NAME:-NoName}"
done

# 4. 삭제할 Attachment ID 입력 및 확인
read -p "❌ Enter Attachment ID to DISASSOCIATE from Route Table $TGW_RT_ID: " DELETE_ATTACH_ID
read -p "⚠️ Are you sure you want to disassociate $DELETE_ATTACH_ID? (yes/no): " CONFIRM

if [[ "$CONFIRM" == "yes" ]]; then
  echo "🚧 Disassociating $DELETE_ATTACH_ID..."
  aws ec2 disassociate-transit-gateway-route-table \
    --transit-gateway-route-table-id "$TGW_RT_ID" \
    --transit-gateway-attachment-id "$DELETE_ATTACH_ID"
  echo "✅ Disassociated $DELETE_ATTACH_ID from $TGW_RT_ID"
else
  echo "🚫 Cancelled"
fi
