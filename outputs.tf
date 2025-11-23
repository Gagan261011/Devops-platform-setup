output "master_public_ip" {
  description = "Public IP of the control plane node"
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the control plane node"
  value       = aws_instance.master.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = [for w in aws_instance.workers : w.public_ip]
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = [for w in aws_instance.workers : w.private_ip]
}

output "kubeconfig_on_master" {
  description = "Path to kubeconfig on the master (SSH with your key to use kubectl)"
  value       = "/home/ubuntu/.kube/config"
}

output "sample_app_url" {
  description = "NodePort URL for the sample nginx app (reachable from your IP)"
  value       = "http://${aws_instance.master.public_ip}:${local.node_port}"
}
