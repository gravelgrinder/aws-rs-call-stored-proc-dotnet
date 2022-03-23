terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}


resource "aws_redshift_subnet_group" "example" {
  name       = "tf-redshift-cluster-sg"
  subnet_ids = local.subnet-ids

  tags = {
    environment = "TF-Example"
  }
}

###############################################################################
### Create Redshift cluster
###############################################################################
resource "aws_redshift_cluster" "example" {
  cluster_identifier        = "tf-redshift-cluster"
  database_name             = "mydb"
  master_username           = "awsuser"
  master_password           = "Mustbe8characters"
  node_type                 = "dc2.large"
  cluster_type              = "single-node"
  cluster_subnet_group_name = aws_redshift_subnet_group.example.name
  skip_final_snapshot       = true
}
###############################################################################


###############################################################################
### Create necessary IAM role for the Lambda Function
###############################################################################
resource "aws_iam_role" "iam_for_lambda" {
  name               = "tf-iam_for_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
###############################################################################


###############################################################################
### Create Security Group for Lambda Function
###############################################################################
resource "aws_security_group" "example" {
  name        = "tf-lambda-sg"
  description = "Allow Lambda to talk to Redshift Cluster"
  vpc_id      = local.vpc-id

  ingress {
    description      = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tf-lambda-sg"
  }
}
###############################################################################



###############################################################################
### Create .Net Lambda Function to call the RS stored proc
###############################################################################
data "archive_file" "example" {
  type         = "zip"
  output_path = "./dist/dotnet_lambda.zip"
  source {
    content = file("dotnet_lambda/main.cs")
    filename = "main.cs"
  }
}

resource "aws_lambda_function" "example_lambda" {
  filename         = "${data.archive_file.example.output_path}"
  function_name    = "tf-example-lambda"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "main.lambda_handler"
  source_code_hash = "${data.archive_file.example.output_base64sha256}"
  #vpc_config {
  #    subnet_ids            = local.subnet-ids
  #    security_group_ids    = [aws_security_group.example.id]
  #}
  runtime          = "dotnet6"
  environment {
    variables = {
        fname = "Devin"
    }
  }
}
###############################################################################




output "rs_cluster_endpoint" {
  value = aws_redshift_cluster.example.endpoint
}

output "rs_cluster_port" {
  value = aws_redshift_cluster.example.port
}

locals {
    iam_role_arn      = "arn:aws:iam::614129417617:role/service-role/AWSGlueServiceRole-TestRole"
    subnet-ids        = ["subnet-069a69e50bd1ebb23", "subnet-0871b35cbe9d0c1cf"]
    vpc-id            = "vpc-00b09e53c6e62a994"
}