#!/usr/bin/env bash
# Desde el host Proxmox: crea el clúster con kubeadm (control plane + 3 workers) e instala Flannel.
# Requiere haber corrido preparar-nodos.sh.   Uso:  bash scripts/proxmox/instalar-kubernetes.sh
set -euo pipefail

CP=10.10.10.10
WORKERS="10.10.10.11 10.10.10.12 10.10.10.13"
SSH="ssh -o StrictHostKeyChecking=accept-new"

if $SSH "kube@${CP}" "test -f /etc/kubernetes/admin.conf"; then
  echo ">> El control plane ya estaba inicializado"
else
  echo ">> kubeadm init en k8s-cp"
  $SSH "kube@${CP}" "sudo kubeadm init --apiserver-advertise-address=${CP} --pod-network-cidr=10.244.0.0/16"
fi

echo ">> kubectl para el usuario kube"
$SSH "kube@${CP}" 'mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config'

echo ">> Red de pods (Flannel)"
$SSH "kube@${CP}" "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

JOIN=$($SSH "kube@${CP}" "sudo kubeadm token create --print-join-command")
for ip in $WORKERS; do
  if $SSH "kube@${ip}" "test -f /etc/kubernetes/kubelet.conf"; then
    echo ">> ${ip} ya pertenece al clúster"
  else
    echo ">> Uniendo ${ip}"
    $SSH "kube@${ip}" "sudo ${JOIN}"
  fi
done

echo ">> Etiqueta de rol worker"
for n in k8s-w1 k8s-w2 k8s-w3; do
  $SSH "kube@${CP}" "kubectl label node ${n} node-role.kubernetes.io/worker= --overwrite" >/dev/null
done

echo ">> Esperando nodos Ready"
$SSH "kube@${CP}" "kubectl wait --for=condition=Ready node --all --timeout=300s && kubectl get nodes -o wide"
