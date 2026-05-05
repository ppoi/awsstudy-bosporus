
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

variable "parent_project_id" {
  description = "Parent Project Identifier"
  type        = string
  nullable    = false
  default     = "bosporus"
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

variable "flow_log_role_arn" {
  description = "フローログ記録のためのIAMロールARN"
  type        = string
}

variable "tgw_id" {
  description = "接続するTransit GatewayのID"
  type        = string
}

variable "vpc_specs" {
  description = "Egress VPCの定義"
  type = object({
    ipv4_cidr = string
    application_subnet = map(object({
      network_address = number
    }))
    application_ipv6only_subnet = map(object({
      network_address = number
    }))
    tgw_subnet = map(object({
      network_address = number
    }))
  })
}
