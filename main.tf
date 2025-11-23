#############################################
# Simple kubeadm-based Kubernetes cluster on AWS
# How to use:
#   1) terraform init
#   2) terraform apply -auto-approve
#   3) SSH to the master: ssh -i <your_key.pem> ubuntu@<master_public_ip>
#   4) Verify cluster: kubectl get nodes (already installed on master)
#   5) Sample app exposed via NodePort (see outputs for URL)
#############################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fetch AZs to pick the first one for the single public subnet
data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Ubuntu 22.04 LTS (Jammy) AMI for the region
data "aws_ami" "ubuntu_2204" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  master_name  = "k8s-master-1"
  worker_names = ["k8s-worker-1", "k8s-worker-2"]
}
