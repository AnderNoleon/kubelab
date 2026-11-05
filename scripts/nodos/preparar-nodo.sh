#!/usr/bin/env bash
# Prepara un nodo Ubuntu 24.04 para k3s (INF-04).
# Lo ejecuta scripts/proxmox/preparar-nodos.sh en todos los nodos; también se puede correr a mano con sudo.
# k3s trae su propio containerd, flannel, kube-proxy y CoreDNS; aquí solo se agrega lo que falta.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Ejecuta con sudo"; exit 1; }
export DEBIAN_FRONTEND=noninteractive

echo ">> Swap desactivado (las imágenes cloud no traen swap; por si acaso)"
swapoff -a
sed -i '/\sswap\s/ s/^#*/#/' /etc/fstab

echo ">> Cliente NFS (para los volúmenes persistentes) y utilidades"
apt-get update
apt-get install -y nfs-common curl ca-certificates

echo ">> Nombres de los nodos"
grep -q "k8s-cp" /etc/hosts || cat >> /etc/hosts <<EOF
10.10.10.10 k8s-cp
10.10.10.11 k8s-w1
10.10.10.12 k8s-w2
EOF

echo "Nodo $(hostname) listo"
