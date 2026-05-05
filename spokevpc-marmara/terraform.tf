terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.43"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~>2.7"
    }
  }
}
