// sudo yum update -y
// sudo yum install -y golang
// go get github.com/aws/aws-sdk-go-v2/aws
// go get github.com/aws/aws-sdk-go-v2/config
// go get github.com/aws/aws-sdk-go-v2/service/ec2
// go get github.com/aws/aws-sdk-go-v2/service/iam
// go get github.com/aws/aws-sdk-go-v2/service/sts
// go get github.com/aws/aws-sdk-go-v2/service/ec2/types
// go run list-tgw-route-table.go
// How To Build
// go build -o list-tgw-route list-tgw-route-table.go
// ./list-tgw-route
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	ec2 "github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	iam "github.com/aws/aws-sdk-go-v2/service/iam"
	sts "github.com/aws/aws-sdk-go-v2/service/sts"
)

type TGWRouteTableInfo struct {
	ID   string
	Name string
}

func main() {
	ctx := context.TODO()

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("ap-northeast-2"))
	if err != nil {
		log.Fatalf("Config load error: %v", err)
	}

	stsClient := sts.NewFromConfig(cfg)
	idResp, err := stsClient.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	if err != nil {
		log.Fatalf("Failed to get caller identity: %v", err)
	}
	fmt.Println("🧾 AWS 계정 정보")
	fmt.Printf("Account ID    : %s\n", *idResp.Account)

	iamClient := iam.NewFromConfig(cfg)
	aliasResp, _ := iamClient.ListAccountAliases(ctx, &iam.ListAccountAliasesInput{})
	alias := "-"
	if len(aliasResp.AccountAliases) > 0 {
		alias = aliasResp.AccountAliases[0]
	}
	fmt.Printf("Account Alias : %s\n", alias)
	fmt.Println("Region        : ap-northeast-2\n")

	ec2Client := ec2.NewFromConfig(cfg)

	// List all TGW Route Tables
	rtList, err := ec2Client.DescribeTransitGatewayRouteTables(ctx, &ec2.DescribeTransitGatewayRouteTablesInput{})
	if err != nil {
		log.Fatalf("TGW Route Table 조회 실패: %v", err)
	}

	var rtInfos []TGWRouteTableInfo
	fmt.Println("📋 Transit Gateway Route Tables:")
	for i, rt := range rtList.TransitGatewayRouteTables {
		name := "-"
		for _, tag := range rt.Tags {
			if *tag.Key == "Name" {
				name = *tag.Value
				break
			}
		}
		fmt.Printf("%d. %s (Name: %s)\n", i, *rt.TransitGatewayRouteTableId, name)
		rtInfos = append(rtInfos, TGWRouteTableInfo{
			ID:   *rt.TransitGatewayRouteTableId,
			Name: name,
		})
	}

	fmt.Print("\n✅ 조회할 TGW Route Table 번호 또는 ID 입력: ")
	var input string
	fmt.Scanln(&input)

	var selectedRTID string
	index, err := strconv.Atoi(input)
	if err == nil && index >= 0 && index < len(rtInfos) {
		selectedRTID = rtInfos[index].ID
	} else {
		for _, rt := range rtInfos {
			if rt.ID == input {
				selectedRTID = rt.ID
				break
			}
		}
	}

	if selectedRTID == "" {
		fmt.Println("❌ 선택한 TGW Route Table을 찾을 수 없습니다.")
		os.Exit(1)
	}

	fmt.Printf("\n📦 선택된 TGW Route Table ID: %s\n\n", selectedRTID)

	// 조회
	routesResp, err := ec2Client.SearchTransitGatewayRoutes(ctx, &ec2.SearchTransitGatewayRoutesInput{
		TransitGatewayRouteTableId: aws.String(selectedRTID),
		Filters: []ec2types.Filter{
			{
				Name:   aws.String("state"),
				Values: []string{"active", "blackhole"},
			},
		},
		MaxResults: aws.Int32(100),
	})
	if err != nil {
		log.Fatalf("TGW Route 조회 실패: %v", err)
	}

	// 정렬
	sort.Slice(routesResp.Routes, func(i, j int) bool {
		return aws.ToString(routesResp.Routes[i].DestinationCidrBlock) < aws.ToString(routesResp.Routes[j].DestinationCidrBlock)
	})

	fmt.Printf("%-24s %-30s %-30s %-16s %-10s\n", "Destination", "AttachmentId", "Target Name", "Type", "State")
	fmt.Println(strings.Repeat("-", 120))

	for _, route := range routesResp.Routes {
		dest := aws.ToString(route.DestinationCidrBlock)
		state := string(route.State)
		typ := string(route.Type)

		attID := "-"
		attName := "-"
		if len(route.TransitGatewayAttachments) > 0 {
			attID = aws.ToString(route.TransitGatewayAttachments[0].TransitGatewayAttachmentId)

			// 추가 요청으로 Attachment의 Tag(Name) 조회
			attachDesc, err := ec2Client.DescribeTransitGatewayAttachments(ctx, &ec2.DescribeTransitGatewayAttachmentsInput{
				TransitGatewayAttachmentIds: []string{attID},
			})
			if err == nil && len(attachDesc.TransitGatewayAttachments) > 0 {
				for _, tag := range attachDesc.TransitGatewayAttachments[0].Tags {
					if aws.ToString(tag.Key) == "Name" {
						attName = aws.ToString(tag.Value)
						break
					}
				}
			}
		}

		fmt.Printf("%-24s %-30s %-30s %-16s %-10s\n", dest, attID, attName, typ, state)
	}
}
