

resource "aws_ec2_transit_gateway" "tgw" {
  region                             = var.region
  description                        = "Regional Transit Gateway"
  amazon_side_asn                    = var.tgw_asn
  dns_support                        = "enable"
  security_group_referencing_support = "enable"
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  multicast_support                  = "disable"
  auto_accept_shared_attachments     = "disable"
  transit_gateway_cidr_blocks        = []
  vpn_ecmp_support                   = "enable"

  tags = {
    "Name" = "[${var.project_id}]Transit Gateway"
  }
}

resource "aws_cloudwatch_log_group" "tgw_flow_log_all" {
  name              = "/${var.project_id}/flow-logs/tgw/all"
  retention_in_days = 1
  log_group_class   = "STANDARD"
}

resource "aws_flow_log" "tgw_all" {
  iam_role_arn             = var.flow_log_role_arn
  transit_gateway_id       = aws_ec2_transit_gateway.tgw.id
  max_aggregation_interval = 60
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.tgw_flow_log_all.arn

  tags = {
    "Name" = "All Tarffic"
  }
}

resource "aws_vpc" "egress" {
  cidr_block                       = var.egress_vpc_specs.ipv4_cidr
  assign_generated_ipv6_cidr_block = true
  instance_tenancy                 = "default"
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    "Name" = "[${var.project_id}]Egress VPC"
  }
}

resource "aws_cloudwatch_log_group" "eggress_flow_log" {
  name              = "/${var.project_id}/flow-logs/egress/all"
  retention_in_days = var.flow_log_retention_period
  log_group_class   = "STANDARD"
}

resource "aws_flow_log" "egress_all" {
  iam_role_arn         = var.flow_log_role_arn
  vpc_id               = aws_vpc.egress.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.eggress_flow_log.arn

  tags = {
    "Name" = "All Tarffic"
  }
}

resource "aws_internet_gateway" "egress" {
  vpc_id = aws_vpc.egress.id
  tags = {
    "Name" = "[${var.project_id}]Egress VPC IGW"
  }
}

resource "aws_egress_only_internet_gateway" "egress" {
  vpc_id = aws_vpc.egress.id
  tags = {
    "Name" = "[${var.project_id}]Egress VPC Egress-only IGW"
  }
}

resource "aws_subnet" "public" {
  for_each = var.egress_vpc_specs.public_subnet

  vpc_id                                         = aws_vpc.egress.id
  availability_zone                              = var.regions[var.region].availability_zones[each.key].zone_id
  cidr_block                                     = cidrsubnet(aws_vpc.egress.cidr_block, 8, each.value.network_address)
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.egress.ipv6_cidr_block, 8, each.value.network_address)
  assign_ipv6_address_on_creation                = true
  enable_dns64                                   = true
  enable_resource_name_dns_a_record_on_launch    = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = {
    "Name" = "[${var.project_id}]Public Subnet(${each.key})"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.egress.id
  tags = {
    "Name" = "[${var.project_id}]Public Route Table"
  }
}

resource "aws_route" "public_igw_ipv4" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.egress.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "public_igw_ipv6" {
  route_table_id              = aws_route_table.public.id
  gateway_id                  = aws_internet_gateway.egress.id
  destination_ipv6_cidr_block = "::/0"
}

resource "aws_route_table_association" "public" {
  for_each = var.egress_vpc_specs.public_subnet

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[each.key].id
}

resource "aws_subnet" "tgw" {
  for_each = var.egress_vpc_specs.tgw_subnet

  vpc_id                          = aws_vpc.egress.id
  availability_zone               = var.regions[var.region].availability_zones[each.key].zone_id
  cidr_block                      = cidrsubnet(aws_vpc.egress.cidr_block, 8, each.value.network_address)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.egress.ipv6_cidr_block, 8, each.value.network_address)
  assign_ipv6_address_on_creation = true

  tags = {
    "Name" = "[${var.project_id}]TGW Subnet(${each.key})"
  }
}

resource "aws_route_table" "tgw" {
  for_each = var.egress_vpc_specs.tgw_subnet

  vpc_id = aws_vpc.egress.id

  tags = {
    "Name" = "[${var.project_id}]TGW Route Table(${each.key})"
  }
}

resource "aws_route_table_association" "tgw" {
  for_each = var.egress_vpc_specs.tgw_subnet

  route_table_id = aws_route_table.tgw[each.key].id
  subnet_id      = aws_subnet.tgw[each.key].id
}

resource "aws_eip" "nat" {
  for_each = var.egress_vpc_specs.public_subnet

  domain = "vpc"

  tags = {
    "Name" = "[${var.project_id}]NAT Gateway[${each.key}]"
  }
}

resource "aws_nat_gateway" "egress" {
  for_each = var.egress_vpc_specs.public_subnet

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id


  tags = {
    "Name" = "[${var.project_id}]NAT Gateway[${each.key}]"
  }

  depends_on = [
    aws_internet_gateway.egress
  ]
}

resource "aws_route" "tgw_nat64" {
  for_each = var.egress_vpc_specs.tgw_subnet

  route_table_id              = aws_route_table.tgw[each.key].id
  nat_gateway_id              = aws_nat_gateway.egress[each.key].id
  destination_ipv6_cidr_block = "64:ff9b::/96"
}

resource "aws_route" "tgw_ipv4" {
  for_each = var.egress_vpc_specs.tgw_subnet

  route_table_id         = aws_route_table.tgw[each.key].id
  nat_gateway_id         = aws_nat_gateway.egress[each.key].id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = aws_vpc.egress.id
  subnet_ids                                      = values(aws_subnet.tgw)[*].id
  ipv6_support                                    = "enable"
  dns_support                                     = "enable"
  appliance_mode_support                          = "disable"
  security_group_referencing_support              = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    "Name" = "[${var.project_id}]Egress VPC Attachment"
  }
}

resource "aws_ec2_transit_gateway_route_table" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "[${var.project_id}]Egress Route Table"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
}

resource "aws_ec2_transit_gateway_route_table" "spoke_vpcs" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "[${var.project_id}]Spoke VPCs Route Table"
  }
}

resource "aws_ec2_transit_gateway_route" "spoke_to_egress_nat64" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_vpcs.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  destination_cidr_block         = "64:ff9b::/96"
}

resource "aws_ec2_transit_gateway_route" "spoke_to_egress_ipv4" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_vpcs.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  destination_cidr_block         = "0.0.0.0/0"
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_vpcs" {
  for_each = var.spoke_vpcs

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_vpcs.id
  transit_gateway_attachment_id  = each.value.tgw_attachment_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_vpcs" {
  for_each = var.spoke_vpcs

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
  transit_gateway_attachment_id  = each.value.tgw_attachment_id
}

resource "aws_route" "pullic_route_return_path_ipv4" {
  for_each = var.spoke_vpcs

  route_table_id         = aws_route_table.public.id
  destination_cidr_block = each.value.ipv4_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.egress]
}

resource "aws_route" "pullic_route_return_path_ipv6" {
  for_each = var.spoke_vpcs

  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = each.value.ipv6_cidr_block
  transit_gateway_id          = aws_ec2_transit_gateway.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.egress]
}
