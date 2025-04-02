// sudo yum update -y
// sudo yum install -y golang
// go get github.com/aws/aws-sdk-go-v2/aws
// go get github.com/aws/aws-sdk-go-v2/config
// go get github.com/aws/aws-sdk-go-v2/service/ec2
// go get github.com/aws/aws-sdk-go-v2/service/iam
// go get github.com/aws/aws-sdk-go-v2/service/sts
// go get github.com/aws/aws-sdk-go-v2/service/ec2/types
// go run list-vpc-route.go
// How To Build
// go build -o list-vpc-route list-vpc-route.go
// ./list-vpc-route

package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	ec2 "github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

type VPCInfo struct {
	ID   string
	Name string
	CIDR string
}

func getResourceName(ctx context.Context, client *ec2.Client, id string) string {
	tagValue := "-"
	switch {
	case strings.HasPrefix(id, "tgw-"):
		out, _ := client.DescribeTransitGateways(ctx, &ec2.DescribeTransitGatewaysInput{
			TransitGatewayIds: []string{id},
		})
		if len(out.TransitGateways) > 0 {
			for _, tag := range out.TransitGateways[0].Tags {
				if *tag.Key == "Name" {
					tagValue = *tag.Value
					break
				}
			}
		}
	case strings.HasPrefix(id, "igw-"):
		out, _ := client.DescribeInternetGateways(ctx, &ec2.DescribeInternetGatewaysInput{
			InternetGatewayIds: []string{id},
		})
		if len(out.InternetGateways) > 0 {
			for _, tag := range out.InternetGateways[0].Tags {
				if *tag.Key == "Name" {
					tagValue = *tag.Value
					break
				}
			}
		}
	case strings.HasPrefix(id, "vpce-"):
		out, _ := client.DescribeVpcEndpoints(ctx, &ec2.DescribeVpcEndpointsInput{
			VpcEndpointIds: []string{id},
		})
		if len(out.VpcEndpoints) > 0 {
			for _, tag := range out.VpcEndpoints[0].Tags {
				if *tag.Key == "Name" {
					tagValue = *tag.Value
					break
				}
			}
		}
	case strings.HasPrefix(id, "nat-"):
		out, _ := client.DescribeNatGateways(ctx, &ec2.DescribeNatGatewaysInput{
			NatGatewayIds: []string{id},
		})
		if len(out.NatGateways) > 0 {
			for _, tag := range out.NatGateways[0].Tags {
				if *tag.Key == "Name" {
					tagValue = *tag.Value
					break
				}
			}
		}
	case strings.HasPrefix(id, "eni-"):
		out, _ := client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
			NetworkInterfaceIds: []string{id},
		})
		if len(out.NetworkInterfaces) > 0 {
			for _, tag := range out.NetworkInterfaces[0].TagSet {
				if *tag.Key == "Name" {
					tagValue = *tag.Value
					break
				}
			}
		}
	}
	return tagValue
}

func main() {
	ctx := context.TODO()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("ap-northeast-2"))
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	stsClient := sts.NewFromConfig(cfg)
	idResp, _ := stsClient.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	fmt.Printf("🧾 Account ID: %s\n", *idResp.Account)

	iamClient := iam.NewFromConfig(cfg)
	aliasResp, _ := iamClient.ListAccountAliases(ctx, &iam.ListAccountAliasesInput{})
	if len(aliasResp.AccountAliases) > 0 {
		fmt.Printf("👤 Account Alias: %s\n", aliasResp.AccountAliases[0])
	}
	fmt.Println()

	ec2Client := ec2.NewFromConfig(cfg)

	// List VPCs
	vpcsOutput, _ := ec2Client.DescribeVpcs(ctx, &ec2.DescribeVpcsInput{})
	var vpcs []VPCInfo
	fmt.Println("📋 VPC 목록:")
	fmt.Printf("%-3s %-20s %-20s %-20s\n", "No", "VPC ID", "Name", "CIDR Block")
	for i, vpc := range vpcsOutput.Vpcs {
		name := "-"
		for _, tag := range vpc.Tags {
			if *tag.Key == "Name" {
				name = *tag.Value
				break
			}
		}
		fmt.Printf("%-3d %-20s %-20s %-20s\n", i, *vpc.VpcId, name, *vpc.CidrBlock)
		vpcs = append(vpcs, VPCInfo{ID: *vpc.VpcId, Name: name, CIDR: *vpc.CidrBlock})
	}

	fmt.Print("\n✅ 조회할 VPC (번호 / ID / Name): ")
	var input string
	fmt.Scanln(&input)

	var selectedVpcID string
	if idx, err := strconv.Atoi(input); err == nil && idx >= 0 && idx < len(vpcs) {
		selectedVpcID = vpcs[idx].ID
	} else {
		for _, v := range vpcs {
			if v.ID == input || v.Name == input {
				selectedVpcID = v.ID
				break
			}
		}
	}
	if selectedVpcID == "" {
		fmt.Println("❌ 일치하는 VPC를 찾을 수 없습니다.")
		os.Exit(1)
	}
	fmt.Printf("\n🔍 선택된 VPC ID: %s\n\n", selectedVpcID)

	// Route Tables
	rtOutput, _ := ec2Client.DescribeRouteTables(ctx, &ec2.DescribeRouteTablesInput{
		Filters: []ec2types.Filter{
			{
				Name:   aws.String("vpc-id"),
				Values: []string{selectedVpcID},
			},
		},
	})

	for _, rt := range rtOutput.RouteTables {
		rtName := "-"
		for _, tag := range rt.Tags {
			if *tag.Key == "Name" {
				rtName = *tag.Value
				break
			}
		}
		fmt.Printf("📦 라우팅 테이블: %s (Name: %s)\n", *rt.RouteTableId, rtName)
		fmt.Printf("%-22s %-22s %-30s %-10s %-10s\n", "Destination", "Target", "TargetName", "State", "Propagated")
		fmt.Println(strings.Repeat("-", 100))

		for _, route := range rt.Routes {
			dest := "-"
			if route.DestinationCidrBlock != nil {
				dest = *route.DestinationCidrBlock
			} else if route.DestinationPrefixListId != nil {
				dest = *route.DestinationPrefixListId
			}

			target := "-"
			for _, t := range []*string{
				route.GatewayId,
				route.NatGatewayId,
				route.TransitGatewayId,
				route.VpcPeeringConnectionId,
				route.InstanceId,
				route.LocalGatewayId,
				route.NetworkInterfaceId,
				route.EgressOnlyInternetGatewayId,
			} {
				if t != nil {
					target = *t
					break
				}
			}

			targetName := getResourceName(ctx, ec2Client, target)

			propagated := "false"
			if route.Origin == "EnableVgwRoutePropagation" {
				propagated = "true"
			}

			fmt.Printf("%-22s %-22s %-30s %-10s %-10s\n", dest, target, targetName, route.State, propagated)
		}
		fmt.Println()
	}
}
