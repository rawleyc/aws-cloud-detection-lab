provider "aws" {
  region = "eu-central-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

#Start of cloudtrail setup

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

resource "aws_cloudtrail" "main" {
  name                          = "org-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
}

#End of cloudtrail setup

#Start of VPC logs setup

resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpc/flowlogs"
  retention_in_days = 30
}

resource "aws_iam_role" "flowlogs" {
  name = "vpc-flowlogs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow.arn
  iam_role_arn         = aws_iam_role.flowlogs.arn
}

#End of VPC flow logs setup

#SSM Setup to get bucket names

resource "aws_ssm_parameter" "flow_logs_bucket" {
  name = "/logging/flowlogs/bucket"
  type = String
  value = aws_s3_bucket.flow_logs.bucket
}

resource "aws_instance" "test-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "detection-lab"
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "cloudtrail-logs"
}

resource "aws_s3_bucket" "flow_logs" {
  bucket = "vpc-flow-logs-123599503689"
}


