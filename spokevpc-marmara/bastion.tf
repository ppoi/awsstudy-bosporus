data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "bastion_role" {
  name               = "${var.parent_project_id}-${var.project_id}-BastionRole"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "bastion_logs" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_security_group" "bastion" {
  name        = "${var.parent_project_id}-${var.project_id}-bastion-sg"
  description = "Bastion Security Group"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "bastion_egress_internal" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "Internal"
  self              = true
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

resource "aws_security_group_rule" "bastion_ingress_internal" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  description       = "Internal"
  self              = true
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

resource "aws_security_group_rule" "bastion_egress_ipv4" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "Egress Any(IPv4)"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = "1"
  to_port           = "65535"
  protocol          = "tcp"
}

resource "aws_security_group_rule" "bastion_egress_ipv6" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "Egress Any(IPv6)"
  ipv6_cidr_blocks  = ["::/0"]
  from_port         = "1"
  to_port           = "65535"
  protocol          = "tcp"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.parent_project_id}-${var.project_id}-bastion"
  role = aws_iam_role.bastion_role.name
}

resource "aws_instance" "bastion_dualstack" {
  ami                    = "ami-0a21a03072be95559"
  availability_zone      = var.regions[var.region].availability_zones["A"].zone_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.application["A"].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  volume_tags = {
    "awsAppliction" = var.aws_application_arn
  }
  tags = {
    "Name" = "[${var.parent_project_id}:${var.project_id}]Bastion(dualstack)"
  }
}

resource "aws_instance" "bastion_ipv6only" {
  ami                    = "ami-0a21a03072be95559"
  availability_zone      = var.regions[var.region].availability_zones["B"].zone_id
  instance_type          = "t3.micro"
  key_name               = "marmara"
  subnet_id              = aws_subnet.application_ipv6only["B"].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  volume_tags = {
    "awsAppliction" = var.aws_application_arn
  }
  tags = {
    "Name" = "[${var.parent_project_id}:${var.project_id}]Bastion(IPv6 only)"
  }
}
