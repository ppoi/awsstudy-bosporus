
###### Spoke VPC

resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_specs.ipv4_cidr
  assign_generated_ipv6_cidr_block = true
  instance_tenancy                 = "default"
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    "Name" = "[${var.parent_project_id}:${var.project_id}]VPC"
  }
}

resource "aws_cloudwatch_log_group" "marmara_flow_log" {
  name              = "/bosporus/flow-logs/${var.project_id}/all"
  retention_in_days = 3
  log_group_class   = "STANDARD"
}

resource "aws_flow_log" "all" {
  iam_role_arn         = var.flow_log_role_arn
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.marmara_flow_log.arn

  tags = {
    "Name" = "All Tarffic"
  }
}

resource "aws_subnet" "application" {
  for_each = var.vpc_specs.application_subnet

  vpc_id                                         = aws_vpc.main.id
  availability_zone                              = var.regions[var.region].availability_zones[each.key].zone_id
  cidr_block                                     = cidrsubnet(aws_vpc.main.cidr_block, 8, each.value.network_address)
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value.network_address)
  assign_ipv6_address_on_creation                = true
  enable_dns64                                   = true
  enable_resource_name_dns_a_record_on_launch    = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = {
    "Name" = "[bosporus:${var.project_id}]Application[${each.key}]"
  }
}

resource "aws_subnet" "application_ipv6only" {
  for_each = var.vpc_specs.application_ipv6only_subnet

  vpc_id                                         = aws_vpc.main.id
  availability_zone                              = var.regions[var.region].availability_zones[each.key].zone_id
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value.network_address)
  ipv6_native                                    = true
  assign_ipv6_address_on_creation                = true
  enable_dns64                                   = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = {
    "Name" = "[bosporus:${var.project_id}]Application(IPv6-pnly)[${each.key}]"
  }
}

resource "aws_route_table" "application" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "[${var.project_id}:marmara]Application Route Table"
  }
}

resource "aws_route_table_association" "application" {
  for_each = var.vpc_specs.application_subnet

  route_table_id = aws_route_table.application.id
  subnet_id      = aws_subnet.application[each.key].id
}

resource "aws_route_table_association" "application_ipv6only" {
  for_each = var.vpc_specs.application_ipv6only_subnet

  route_table_id = aws_route_table.application.id
  subnet_id      = aws_subnet.application_ipv6only[each.key].id
}

resource "aws_subnet" "tgw" {
  for_each = var.vpc_specs.tgw_subnet

  vpc_id                          = aws_vpc.main.id
  availability_zone               = var.regions[var.region].availability_zones[each.key].zone_id
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 8, each.value.network_address)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value.network_address)
  assign_ipv6_address_on_creation = true

  tags = {
    "Name" = "[${var.parent_project_id}:${var.project_id}]TGW(${each.key})"
  }
}

resource "aws_route_table" "tgw" {
  for_each = var.vpc_specs.tgw_subnet

  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "[${var.parent_project_id}:${var.project_id}]TGW Route Table(${each.key})"
  }
}

resource "aws_route_table_association" "tgw" {
  for_each = var.vpc_specs.tgw_subnet

  route_table_id = aws_route_table.tgw[each.key].id
  subnet_id      = aws_subnet.tgw[each.key].id
}


resource "aws_ec2_transit_gateway_vpc_attachment" "marmara" {
  transit_gateway_id                              = var.tgw_id
  vpc_id                                          = aws_vpc.main.id
  subnet_ids                                      = values(aws_subnet.tgw)[*].id
  ipv6_support                                    = "enable"
  dns_support                                     = "enable"
  appliance_mode_support                          = "disable"
  security_group_referencing_support              = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    "Name" = "[${var.parent_project_id}:${var.project_id}]VPC Attachment"
  }
}

resource "aws_egress_only_internet_gateway" "igw_ipv6" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "[${var.parent_project_id}:${var.project_id}]Egress-only IGW"
  }
}

resource "aws_route" "application_egress_ipv6" {
  route_table_id              = aws_route_table.application.id
  egress_only_gateway_id      = aws_egress_only_internet_gateway.igw_ipv6.id
  destination_ipv6_cidr_block = "::/0"
}

resource "aws_route" "application_egress_nat64" {
  route_table_id              = aws_route_table.application.id
  transit_gateway_id          = var.tgw_id
  destination_ipv6_cidr_block = "64:ff9b::/96"

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.marmara]
}

resource "aws_route" "application_egress_ipv4" {
  route_table_id         = aws_route_table.application.id
  transit_gateway_id     = var.tgw_id
  destination_cidr_block = "0.0.0.0/0"

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.marmara]
}

resource "aws_security_group" "application" {
  name        = "${var.parent_project_id}-${var.project_id}-application-sg"
  description = "Application Security Group"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "application_egress_internal" {
  security_group_id = aws_security_group.application.id
  type              = "egress"
  description       = "Internal"
  self              = true
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

resource "aws_security_group_rule" "application_ingress_internal" {
  security_group_id = aws_security_group.application.id
  type              = "ingress"
  description       = "Internal"
  self              = true
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

resource "aws_security_group_rule" "egress_ipv4" {
  security_group_id = aws_security_group.application.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  description       = "Egress HTTPS(IPv4)"
}

resource "aws_security_group_rule" "egress_ipv6" {
  security_group_id = aws_security_group.application.id
  type              = "egress"
  ipv6_cidr_blocks  = ["::/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  description       = "Egress HTTPS(IPv6)"
}
