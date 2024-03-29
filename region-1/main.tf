# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 0.12.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Set the AWS REGION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "all" {}

data "aws_route_table" "shared_services" {
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
  vpc_id     = "${module.vpc_shared_services.vpc_id}"

  filter {
    name   = "tag:Name"
    values = ["${var.resource_name}shared_services"]
  }
}

data "aws_route_table" "vpc_a" {
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
  vpc_id     = "${module.vpc_a.vpc_id}"

  filter {
    name   = "tag:Name"
    values = ["${var.resource_name}A"]
  }
}

data "aws_route_table" "vpc_b" {
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
  vpc_id     = "${module.vpc_b.vpc_id}"

  filter {
    name   = "tag:Name"
    values = ["${var.resource_name}B"]
  }
}


#----------------
#create ssh key
#_________________

module "ssh_keypair_aws" {
  source = "github.com/dawright22/hashicorp-modules/ssh-keypair-aws"
  create = "${var.create}"
  name   = "${var.name}-region-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the basic network via terrafrom registery VPC module
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_a" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"
  name   = "${var.resource_name}"
  cidr   = var.cidr_a

  enable_dns_hostnames = true
  enable_dns_support   = true
  azs                  = data.aws_availability_zones.all.names
  public_subnets       = var.public_subnets_a
  tags = {
    Terraform = "true"
    Name      = "${var.resource_name}A"
  }
}

module "vpc_b" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"
  name   = "${var.resource_name}"
  cidr   = var.cidr_b

  enable_dns_hostnames = true
  enable_dns_support   = true
  azs                  = data.aws_availability_zones.all.names
  public_subnets       = var.public_subnets_b
  tags = {
    Terraform = "true"
    Name      = "${var.resource_name}B"
  }
}

module "vpc_shared_services" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"
  name   = "${var.resource_name}"
  cidr   = var.cidr_shared_services

  enable_dns_hostnames = true
  enable_dns_support   = true
  azs                  = data.aws_availability_zones.all.names
  public_subnets       = var.public_subnets_shared_services
  tags = {
    Terraform = "true"
    Name      = "${var.resource_name}shared_services"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# Create the Vault  via terrafrom registery  module
# ---------------------------------------------------------------------------------------------------------------------

# module "Vault" {
#   source       = "../modules/terraform-aws-vault"
#   ssh_key_name = "${module.ssh_keypair_aws.name}"
#   vpc_id       = "${module.vpc_shared_services.vpc_id}"
#   vpc_tags = {
#     Name = "${var.resource_name}shared_services"
#   }
#   subnet_tags = {
#     Name = "${var.resource_name}shared_services"
#   }
# }

#create transit gateway for region 1

resource "aws_ec2_transit_gateway" "region_A-tgw" {
  description                     = "Transit Gateway scenario with multiple VPCs."
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags = {
    Name = "${var.resource_name}tgw_A"
  }
}

# attach transit GW to VPC_A

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-att-region_A" {
  subnet_ids                                      = "${module.vpc_a.public_subnets}"
  transit_gateway_id                              = "${aws_ec2_transit_gateway.region_A-tgw.id}"
  vpc_id                                          = "${module.vpc_a.vpc_id}"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "tgw-region-1-vpc_a"
  }
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
}

# attach transit GW to VPC_B
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-att-region_B" {
  subnet_ids                                      = "${module.vpc_b.public_subnets}"
  transit_gateway_id                              = "${aws_ec2_transit_gateway.region_A-tgw.id}"
  vpc_id                                          = "${module.vpc_b.vpc_id}"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "tgw-att-vpc_b"
  }
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
}

# attach transit GW to VPC_shared_services
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-att-region_shared_services" {
  subnet_ids                                      = "${module.vpc_shared_services.public_subnets}"
  transit_gateway_id                              = "${aws_ec2_transit_gateway.region_A-tgw.id}"
  vpc_id                                          = "${module.vpc_shared_services.vpc_id}"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "tgw-att-vpc_shared_services"
  }
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
}
# Route Tables

resource "aws_ec2_transit_gateway_route_table" "tgw-att-vpc_a-rt" {
  transit_gateway_id = "${aws_ec2_transit_gateway.region_A-tgw.id}"
  tags = {
    Name = "tgw-att-vpc_a-rt"
  }
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
}

resource "aws_ec2_transit_gateway_route_table" "tgw-att-vpc_b-rt" {
  transit_gateway_id = "${aws_ec2_transit_gateway.region_A-tgw.id}"
  tags = {
    Name = "tgw-att-vpc_b-rt"
  }
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
}

resource "aws_ec2_transit_gateway_route_table" "tgw-att-vpc_shared_services-rt" {
  transit_gateway_id = "${aws_ec2_transit_gateway.region_A-tgw.id}"
  tags = {
    Name = "tgw-att-vpc_shared_services-rt"
  }
  depends_on = ["aws_ec2_transit_gateway.region_A-tgw"]
}


# Add routes for intra VPC routing

resource "aws_route" "route_shared_service_to_vpc_a" {
  route_table_id         = "${data.aws_route_table.shared_services.id}"
  destination_cidr_block = var.cidr_a
  transit_gateway_id     = "${aws_ec2_transit_gateway.region_A-tgw.id}"
}

resource "aws_route" "route_shared_service_to_vpc_b" {
  route_table_id         = "${data.aws_route_table.shared_services.id}"
  destination_cidr_block = var.cidr_b
  transit_gateway_id     = "${aws_ec2_transit_gateway.region_A-tgw.id}"
}

resource "aws_route" "route_vpc_a_to_shared_services" {
  route_table_id         = "${data.aws_route_table.vpc_a.id}"
  destination_cidr_block = var.cidr_shared_services
  transit_gateway_id     = "${aws_ec2_transit_gateway.region_A-tgw.id}"
}

resource "aws_route" "route_vpc_b_to_shared_services" {
  route_table_id         = "${data.aws_route_table.vpc_b.id}"
  destination_cidr_block = var.cidr_shared_services
  transit_gateway_id     = "${aws_ec2_transit_gateway.region_A-tgw.id}"
}


# # Route Tables Associations

resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-vpc-a-assoc" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_A.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_a-rt.id}"
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-vpc-b-assoc" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_B.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_b-rt.id}"
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-vpc-shared_services-assoc" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_shared_services.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_shared_services-rt.id}"
}

# # Route Tables Propagations

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-vpc-a" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_A.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_a-rt.id}"
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-shared_services-vpc-a" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_A.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_shared_services-rt.id}"
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-vpc-b" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_B.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_b-rt.id}"
}
resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-shared_services-vpc-b" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_B.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_shared_services-rt.id}"
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-vpc-shared_services" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_shared_services.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_shared_services-rt.id}"
}
resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-vpc-shared_services-vpc-a" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_shared_services.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_a-rt.id}"
}
resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-vpc-shared_services-vpc-b" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tgw-att-region_shared_services.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tgw-att-vpc_b-rt.id}"
}

