variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "key_pair_name" {
  description = "Existing AWS key pair name for SSH"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the private key that matches the key pair (used for provisioning)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "my_ip_cidr" {
  description = "Your public IP/CIDR for SSH/API/NodePort access (e.g., 1.2.3.4/32)"
  type        = string
}

variable "pod_cidr" {
  description = "Pod network CIDR used by kubeadm and the CNI plugin"
  type        = string
  default     = "10.244.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for all nodes"
  type        = string
  default     = "t3.medium"
}
