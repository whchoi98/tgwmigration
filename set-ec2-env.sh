#!/bin/bash

declare -a EC2_NAMES=(
  "VPCO2-Private-B-10.2.24.102"
  "VPCO2-Private-B-10.2.24.101"
  "VPCO2-Private-A-10.2.20.102"
  "VPCO2-Private-A-10.2.20.101"
  "VPC01-Private-B-10.1.24.102"
  "VPC01-Private-B-10.1.24.101"
  "VPCO1-Private-A-10.1.20.102"
  "VPCO1-Private-A-10.1.20.101"
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

for name in "${EC2_NAMES[@]}"; do
  var_name=$(echo $name | tr '.-' '_' | tr '[:lower:]' '[:upper:]')
  instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$name" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [[ -n "$instance_id" ]]; then
    echo "export EC2_$var_name=$instance_id"
  else
    echo "# Not found: $name"
  fi
done
