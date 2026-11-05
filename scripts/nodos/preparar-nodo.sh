#!/usr/bin/env bash
# Prepara un nodo Ubuntu 24.04 para Kubernetes con kubeadm (INF-04).
# Lo ejecuta scripts/proxmox/preparar-nodos.sh en los 4 nodos; también se puede correr a mano con sudo.
set -euo pipefail

K8S_VERSION="v1.36"

[[ $EUID -eq 0 ]] || { echo "Ejecuta con sudo"; exit 1; }
export DEBIAN_FRONTEND=noninteractive

echo ">> Swap desactivado"
swapoff -a
sed -i '/\sswap\s/ s/^#*/#/' /etc/fstab

echo ">> Módulos y red del kernel"
printf "overlay\nbr_netfilter\n" > /etc/modules-load.d/k8s.conf
modprobe overlay
modprobe br_netfilter
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null

echo ">> containerd + cliente NFS"
apt-get update
apt-get install -y containerd nfs-common apt-transport-https ca-certificates curl gpg
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
grep -q 'SystemdCgroup = true' /etc/containerd/config.toml \
  || { echo "ERROR: no se pudo activar SystemdCgroup en containerd"; exit 1; }
systemctl restart containerd
systemctl enable containerd

echo ">> kubeadm, kubelet y kubectl ${K8S_VERSION}"
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

echo ">> Nombres de los nodos"
grep -q "k8s-cp" /etc/hosts || cat >> /etc/hosts <<EOF
10.10.10.10 k8s-cp
10.10.10.11 k8s-w1
10.10.10.12 k8s-w2
10.10.10.13 k8s-w3
EOF

echo "Nodo $(hostname) listo: $(kubeadm version -o short)"
