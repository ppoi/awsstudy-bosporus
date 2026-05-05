provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "awsApplication" = var.aws_application_arn
    }
  }
}
