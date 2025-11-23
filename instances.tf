# Control plane node
resource "aws_instance" "master" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.k8s_public.id
  vpc_security_group_ids      = [aws_security_group.k8s.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name

  tags = {
    Name = local.master_name
    role = "master"
  }
}

# Worker nodes
resource "aws_instance" "workers" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.k8s_public.id
  vpc_security_group_ids      = [aws_security_group.k8s.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name

  tags = {
    Name = local.worker_names[count.index]
    role = "worker"
  }
}
