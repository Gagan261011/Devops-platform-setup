locals {
  ssh_private_key = file(var.ssh_private_key_path)
  node_port       = 30080
}

# Bootstrap the control plane node with kubeadm and Calico
resource "null_resource" "master_provision" {
  depends_on = [aws_instance.master]

  triggers = {
    instance_id = aws_instance.master.id
  }

  connection {
    type        = "ssh"
    host        = aws_instance.master.public_ip
    user        = "ubuntu"
    private_key = local.ssh_private_key
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [<<-EOF
      cat <<'SCRIPT' | sudo tee /tmp/master-setup.sh
      #!/usr/bin/env bash
      set -euo pipefail

      # Base packages and Kubernetes repo
      apt-get update
      apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
      chmod 644 /etc/apt/keyrings/kubernetes-archive-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
      apt-get update

      # Kernel modules and sysctl required by Kubernetes
      modprobe overlay
      modprobe br_netfilter
      cat >/etc/modules-load.d/containerd.conf <<'EOM'
      overlay
      br_netfilter
      EOM
      cat >/etc/sysctl.d/99-kubernetes-cri.conf <<'EOM'
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1
      EOM
      sysctl --system

      # Disable swap as required by kubelet
      swapoff -a
      sed -i '/ swap / s/^/#/' /etc/fstab

      # Install containerd and Kubernetes components
      apt-get install -y containerd kubelet kubeadm kubectl
      apt-mark hold kubelet kubeadm kubectl

      mkdir -p /etc/containerd
      if [ ! -f /etc/containerd/config.toml ]; then
        containerd config default | tee /etc/containerd/config.toml
      fi
      sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
      systemctl restart containerd
      systemctl enable containerd kubelet

      if [ ! -f /etc/kubernetes/admin.conf ]; then
        kubeadm reset -f || true
        kubeadm init --apiserver-advertise-address=${aws_instance.master.private_ip} --pod-network-cidr=${var.pod_cidr} --node-name=${local.master_name}

        mkdir -p /home/ubuntu/.kube
        cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
        chown ubuntu:ubuntu /home/ubuntu/.kube/config

        # Install Calico CNI
        sudo -u ubuntu kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml
      fi

      # Always refresh join command and serve it for workers
      kubeadm token create --ttl 0 --print-join-command > /tmp/kubeadm_join_cmd.sh
      chmod +x /tmp/kubeadm_join_cmd.sh

      if ! pgrep -f "python3 -m http.server 9999" >/dev/null; then
        nohup python3 -m http.server 9999 --directory /tmp >/tmp/http.log 2>&1 &
      fi
      SCRIPT

      sudo bash /tmp/master-setup.sh
    EOF
    ]
  }
}

# Bootstrap workers and join them to the cluster
resource "null_resource" "worker_provision" {
  count      = 2
  depends_on = [null_resource.master_provision]

  triggers = {
    instance_id = aws_instance.workers[count.index].id
  }

  connection {
    type        = "ssh"
    host        = aws_instance.workers[count.index].public_ip
    user        = "ubuntu"
    private_key = local.ssh_private_key
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [<<-EOF
      cat <<'SCRIPT' | sudo tee /tmp/worker-setup.sh
      #!/usr/bin/env bash
      set -euo pipefail

      # If already joined, skip
      if [ -f /etc/kubernetes/kubelet.conf ]; then
        echo "Node already part of cluster, skipping join."
        exit 0
      fi

      apt-get update
      apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
      chmod 644 /etc/apt/keyrings/kubernetes-archive-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
      apt-get update

      modprobe overlay
      modprobe br_netfilter
      cat >/etc/modules-load.d/containerd.conf <<'EOM'
      overlay
      br_netfilter
      EOM
      cat >/etc/sysctl.d/99-kubernetes-cri.conf <<'EOM'
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1
      EOM
      sysctl --system

      swapoff -a
      sed -i '/ swap / s/^/#/' /etc/fstab

      apt-get install -y containerd kubelet kubeadm kubectl
      apt-mark hold kubelet kubeadm kubectl

      mkdir -p /etc/containerd
      if [ ! -f /etc/containerd/config.toml ]; then
        containerd config default | tee /etc/containerd/config.toml
      fi
      sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
      systemctl restart containerd
      systemctl enable containerd kubelet

      # Fetch join command from master (served on port 9999)
      JOIN_CMD=""
      for i in $(seq 1 30); do
        JOIN_CMD=$(curl -sf http://${aws_instance.master.private_ip}:9999/kubeadm_join_cmd.sh) && break
        echo "Waiting for join command..."
        sleep 10
      done

      if [ -z "$JOIN_CMD" ]; then
        echo "Failed to retrieve join command from master"
        exit 1
      fi

      bash -c "$JOIN_CMD --node-name=${local.worker_names[count.index]}"
      SCRIPT

      sudo bash /tmp/worker-setup.sh
    EOF
    ]
  }
}

# Deploy sample app and verify cluster health
resource "null_resource" "verify_cluster" {
  depends_on = [null_resource.worker_provision]

  triggers = {
    master_id = aws_instance.master.id
  }

  connection {
    type        = "ssh"
    host        = aws_instance.master.public_ip
    user        = "ubuntu"
    private_key = local.ssh_private_key
    timeout     = "10m"
  }

  # Wait for nodes to be Ready and deploy a sample app
  provisioner "remote-exec" {
    inline = [<<-EOF
      cat <<'SCRIPT' | sudo tee /tmp/verify-and-deploy.sh
      #!/usr/bin/env bash
      set -euo pipefail
      export KUBECONFIG=/etc/kubernetes/admin.conf

      # Wait for all nodes to be Ready
      for i in $(seq 1 30); do
        READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -c "Ready" || true)
        TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || true)
        if [ "$TOTAL" -ge 3 ] && [ "$READY" -eq "$TOTAL" ]; then
          echo "All nodes ready ($READY/$TOTAL)"
          break
        fi
        echo "Waiting for nodes to be ready ($READY/$TOTAL)..."
        sleep 10
      done

      READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -c "Ready" || true)
      TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || true)
      if [ "$TOTAL" -lt 3 ] || [ "$READY" -ne "$TOTAL" ]; then
        echo "Nodes not ready after waiting"
        exit 1
      fi

      # Sample nginx Deployment + NodePort Service
      cat <<'MANIFEST' | kubectl apply -f -
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: sample-nginx
        labels:
          app: sample-nginx
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: sample-nginx
        template:
          metadata:
            labels:
              app: sample-nginx
          spec:
            containers:
            - name: nginx
              image: nginx:1.25
              ports:
              - containerPort: 80
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: sample-nginx
        labels:
          app: sample-nginx
      spec:
        type: NodePort
        selector:
          app: sample-nginx
        ports:
        - port: 80
          targetPort: 80
          nodePort: ${local.node_port}
      MANIFEST

      kubectl rollout status deployment/sample-nginx --timeout=120s
      kubectl get nodes -o wide
      kubectl get svc sample-nginx
      SCRIPT

      sudo bash /tmp/verify-and-deploy.sh
    EOF
    ]
  }
}
