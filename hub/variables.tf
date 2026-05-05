
variable "regions" {
  description = "利用可能なリージョンおよびAZの定義"
  type = map(object({
    availability_zones = map(object({
      zone_id = string
    }))
  }))
  default = {
    "ap-northeast-1" = {
      availability_zones = {
        "A" = { zone_id = "ap-northeast-1c" },
        "B" = { zone_id = "ap-northeast-1d" }
      }
    }
  }
}

variable "project_id" {
  description = "Project Identifier"
  type        = string
  nullable    = false
}
variable "aws_application_arn" {
  description = "AWS myApplication ARN"
  type        = string
  nullable    = false
}

variable "region" {
  description = "利用するAWSリージョン"
  type        = string
}

variable "tgw_asn" {
  description = "Transit GatewayのAmazon Side Private Autonomous System Number(ASN)"
  type        = number
  default     = 4200000001
}

variable "flow_log_role_arn" {
  description = "フローログ記録のためのIAMロールARN"
  type        = string
}

variable "flow_log_retention_period" {
  description = "フローログ保存期間(日数)"
  type        = number
  default     = 1
}

variable "egress_vpc_specs" {
  description = "Egress VPCの定義"
  type = object({
    ipv4_cidr = string
    public_subnet = map(object({
      network_address = number
    }))
    tgw_subnet = map(object({
      network_address = number
    }))
  })
}

variable "spoke_vpcs" {
  description = "Egress VPCに接続するスポークVPC設定"
  type = map(object({
    vpc_id            = string
    ipv4_cidr_block   = string
    ipv6_cidr_block   = string
    tgw_attachment_id = string
  }))
  nullable = true
}
