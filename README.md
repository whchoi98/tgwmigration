# 🛰️ TGW Migration with AWS CloudFormation

이 리포지토리는 AWS Transit Gateway (TGW) 기반 네트워크 아키텍처를 구성하고, 기존 DMZ VPC에서 신규 DMZ VPC로 마이그레이션하는 CloudFormation 템플릿과 도구들을 포함합니다.

---

## 📁 프로젝트 구조

| 파일명/스크립트               | 설명                                      |
|------------------------------|-------------------------------------------|
| `1.DMZVPC.yml`               | 기존 DMZ VPC 생성 템플릿                   |
| `2.VPC01.yml`, `3.VPC02.yml` | VPC01, VPC02 생성 템플릿                   |
| `4.TGW.yml`                  | 기존 TGW 생성 및 연결 템플릿               |
| `5.NEWDMZVPC.yml`            | 신규 DMZ VPC 생성 템플릿                   |
| `6.NEWTGW.yml`               | 신규 TGW 생성 및 연결 템플릿               |
| `DMZVPC_migration.sh`        | 기존 DMZVPC의 라우팅을 신규 TGW로 마이그레이션 |
| `restore-dmzvpc-route.sh`    | 마이그레이션을 원복                        |
| `list-vpc-route.go/sh`       | VPC 라우팅 테이블 조회 (Go / Shell)        |
| `list-tgw-route-table.go/sh` | TGW 라우팅 테이블 조회 (Go / Shell)        |

---

## 🚀 시작하기

### 1. 저장소 클론

```bash
git clone https://github.com/whchoi98/tgwmigration.git
cd ~/tgwmigration/
```

## 🏗️ CloudFormation 스택 배포

### 2. 기존 DMZ VPC 배포 (약 7분)
```
export AWS_REGION=ap-northeast-2
BUCKET_NAME=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text)-$(date +%Y%m%d)-cf-template

aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION} && \
aws cloudformation deploy \
  --region ${AWS_REGION} \
  --stack-name DMZVPC \
  --template-file ~/tgwmigration/1.DMZVPC.yml \
  --s3-bucket ${BUCKET_NAME} \
  --capabilities CAPABILITY_NAMED_IAM && \
aws s3 rb s3://${BUCKET_NAME} --force

echo "✅ DMZVPC stacks deployed."
```

### 3.VPC01, VPC02 동시 배포 (약 3분)
```
aws cloudformation deploy --region ap-northeast-2 \
  --stack-name "VPC01" \
  --template-file "~/tgwmigration/2.VPC01.yml" \
  --capabilities CAPABILITY_NAMED_IAM &

aws cloudformation deploy --region ap-northeast-2 \
  --stack-name "VPC02" \
  --template-file "~/tgwmigration/3.VPC02.yml" \
  --capabilities CAPABILITY_NAMED_IAM &

wait
echo "✅ VPC01, VPC02 stacks deployed."
```

### 4. 기존 TGW 배포 (약 3분)
```
source ~/.bash_profile
export AWS_REGION=ap-northeast-2

aws cloudformation deploy \
  --region ${AWS_REGION} \
  --stack-name "TGW" \
  --template-file "~/tgwmigration/4.TGW.yml" \
  --capabilities CAPABILITY_NAMED_IAM
```

### 5. 신규 DMZ VPC 배포 (약 7분)

```
export AWS_REGION=ap-northeast-2
BUCKET_NAME=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text)-$(date +%Y%m%d)-cf-template

aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION} && \
aws cloudformation deploy \
  --region ${AWS_REGION} \
  --stack-name NEWDMZVPC \
  --template-file ~/tgwmigration/5.NEWDMZVPC.yml \
  --s3-bucket ${BUCKET_NAME} \
  --capabilities CAPABILITY_NAMED_IAM && \
aws s3 rb s3://${BUCKET_NAME} --force

echo "✅ NEWDMZVPC stacks deployed."
```

### 6. 신규 TGW 배포 (약 3분)

```
source ~/.bash_profile
export AWS_REGION=ap-northeast-2

aws cloudformation deploy \
  --region ${AWS_REGION} \
  --stack-name "NEWTGW" \
  --template-file "~/tgwmigration/6.NEWTGW.yml" \
  --capabilities CAPABILITY_NAMED_IAM
```

## DMZVPC 마이그레이션
### 7. 마이그레이션 수행

```
cd ~/tgwmigration/
./DMZVPC_migration.sh

### 8. 마이그레이션 원복
cd ~/tgwmigration/
./restore-dmzvpc-route.sh

## 🛠️ 유틸리티 도구
### 🔎 VPC 라우팅 테이블 조회

```
# Shell 버전
```
./list-vpc-route.sh
```

# Golang 버전
```
go run ./list-vpc-route.go
```

### 🔎 TGW 라우팅 테이블 조회

```
# Shell 버전
./list-tgw-route.sh
```
```
# Golang 버전
go run ./list-tgw-route-table.go
```

###  참고 사항
	•	리전은 기본적으로 ap-northeast-2 (서울)을 기준으로 설정되어 있습니다.
	•	CloudFormation 배포는 CAPABILITY_NAMED_IAM 권한이 필요합니다.
	•	Golang CLI 도구 사용 시 Amazon Linux 2 환경에서 Go 1.20+ 설치가 필요합니다.
```
sudo yum update -y
sudo yum install -y golang
```

### 👨‍💻 작성자
최우형 (WooHyung Choi) / GitHub: @whchoi98
