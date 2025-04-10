#!/bin/bash

declare -a EC2_NAMES=(
  "VPC02-Private-B-10.2.24.102"
  "VPC02-Private-B-10.2.24.101"
  "VPC02-Private-A-10.2.20.102"
  "VPC02-Private-A-10.2.20.101"
  "VPC01-Private-B-10.1.24.102"
  "VPC01-Private-B-10.1.24.101"
  "VPC01-Private-A-10.1.20.102"
  "VPC01-Private-A-10.1.20.101"
  "NEWDMZVPC-Private-B-10.21.24.102"
  "NEWDMZVPC-Private-B-10.21.24.101"
  "NEWDMZVPC-Private-A-10.21.20.102"
  "NEWDMZVPC-Private-A-10.21.20.101"
  "EC2VSCodeServer"
  "DMZVPC-Private-B-10.11.24.102"
  "DMZVPC-Private-B-10.11.24.101"
  "DMZVPC-Private-A-10.11.20.102"
  "DMZVPC-Private-A-10.11.20.101"
)

echo "# === EC2 환경변수 설정 (자동 생성됨) ===" >> ~/.bash_profile

for name in "${EC2_NAMES[@]}"; do
  var_name=$(echo "$name" | tr '.-' '_' | tr '[:lower:]' '[:upper:]')
  instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$name" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [[ -n "$instance_id" && "$instance_id" != "None" ]]; then
    echo "export EC2_$var_name=$instance_id" >> ~/.bash_profile
    echo "✅ $name => $instance_id"
  else
    echo "# Not found: $name" >> ~/.bash_profile
    echo "❌ Not found: $name"
  fi
done

echo "🔄 ~/.bash_profile 업데이트 완료. 적용하려면 'source ~/.bash_profile' 실행하세요."
