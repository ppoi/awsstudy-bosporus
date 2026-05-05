output "vpc_id" {
  value = aws_vpc.main.id
}
output "vpc_ipv4_cidr" {
  value = aws_vpc.main.cidr_block
}
output "vpc_ipv6_cidr" {
  value = aws_vpc.main.ipv6_cidr_block
}
output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.marmara.id
}
