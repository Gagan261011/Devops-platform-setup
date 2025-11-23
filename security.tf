# Security group allowing SSH from your IP and all required Kubernetes/control plane traffic
resource "aws_security_group" "k8s" {
  name        = "k8s-lab-sg"
  description = "Allow SSH and Kubernetes traffic"
  vpc_id      = aws_vpc.k8s.id

  # SSH from your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # Kubernetes API from your IP (for kubectl/direct access)
  ingress {
    description = "K8s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # NodePort range for sample app access from your IP
  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # Allow all intra-cluster traffic
  ingress {
    description      = "Cluster internal"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    self             = true
    ipv6_cidr_blocks = []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-lab-sg"
  }
}
