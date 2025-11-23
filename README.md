# Kubernetes on AWS with Terraform (kubeadm)

Spin up a simple 3-node Kubernetes cluster (1 control-plane, 2 workers) on AWS using Terraform and kubeadm. The stack:
- AWS VPC + public subnet, security group, and three t3.medium Ubuntu 22.04 nodes
- Automated bootstrap of containerd, kubelet/kubeadm/kubectl, Calico CNI
- Cluster init on the master, workers join automatically, sample nginx app exposed via NodePort

## What you get
- 1× control-plane EC2 (`k8s-master-1`), 2× worker EC2s (`k8s-worker-1`, `k8s-worker-2`)
- Calico networking, pod CIDR default `10.244.0.0/16`
- Sample app: `sample-nginx` served on NodePort `30080`
- Outputs: public/private IPs, kubeconfig path on master, sample app URL

## Prerequisites
- Terraform ≥ 1.6
- AWS credentials configured (env vars or `~/.aws/credentials`)
- An existing AWS key pair name and matching private key file on your machine
- Your public IP in CIDR form (e.g., `1.2.3.4/32`)

## Quick start
1) Init:
```bash
terraform init
```
2) Apply (fill in your values):
```bash
terraform apply \
  -var "key_pair_name=YOUR_KEYPAIR" \
  -var "ssh_private_key_path=~/.ssh/YOUR_KEY.pem" \
  -var "my_ip_cidr=1.2.3.4/32"
```
3) After apply, note outputs for IPs and sample app URL.

## Verify the cluster
- SSH to master:
```bash
ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@<master_public_ip>
```
- Check nodes and services (kubeconfig already at `/home/ubuntu/.kube/config`):
```bash
kubectl --kubeconfig /home/ubuntu/.kube/config get nodes
kubectl --kubeconfig /home/ubuntu/.kube/config get svc sample-nginx
```
- Hit the sample app from your allowed IP:
```bash
curl http://<any_node_public_ip>:30080
```

## Customize
- `variables.tf` lets you tweak region, VPC/subnet CIDRs, pod CIDR, instance type.
- Swap Calico for another CNI by changing the manifest apply in `provisioning.tf`.

## Cleanup
Destroy everything when done:
```bash
terraform destroy \
  -var "key_pair_name=YOUR_KEYPAIR" \
  -var "ssh_private_key_path=~/.ssh/YOUR_KEY.pem" \
  -var "my_ip_cidr=1.2.3.4/32"
```

## Troubleshooting
- `kubectl` points to localhost:8080: ensure you use `--kubeconfig /home/ubuntu/.kube/config` (or `export KUBECONFIG=/etc/kubernetes/admin.conf` as root).
- Nodes not Ready: give Calico a minute, then check `kubectl get pods -A` and `sudo journalctl -xeu kubelet`.
