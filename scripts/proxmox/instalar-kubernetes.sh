#!/usr/bin/env bash
# Desde el host Proxmox: crea el clúster k3s (1 control plane + N workers).
# Requiere haber corrido preparar-nodos.sh.
#   bash scripts/proxmox/instalar-kubernetes.sh              (2 workers)
#   WORKERS=1 bash scripts/proxmox/instalar-kubernetes.sh    (1 worker)
#
# Se desactivan los componentes que k3s trae de serie porque el proyecto instala los suyos con Argo CD:
#   traefik (usamos nuestro Traefik), servicelb (usamos MetalLB),
#   local-storage (usamos NFS) y metrics-server (lo instala Argo CD).
# El instalador de k3s usa sudo por su cuenta cuando no corre como root.
# El control plane lleva el taint NoSchedule: no ejecuta las aplicaciones (INF-05).
set -euo pipefail

WORKERS="${WORKERS:-2}"
CP=10.10.10.10
SSH="ssh -o StrictHostKeyChecking=accept-new"

if $SSH "kube@${CP}" "test -f /etc/rancher/k3s/k3s.yaml"; then
  echo ">> k3s ya estaba instalado en k8s-cp"
else
  echo ">> Instalando k3s (server) en k8s-cp"
  $SSH "kube@${CP}" "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - server \
    --node-ip ${CP} \
    --disable traefik --disable servicelb --disable local-storage --disable metrics-server \
    --node-taint node-role.kubernetes.io/control-plane:NoSchedule \
    --write-kubeconfig-mode 644"
fi

echo ">> kubectl para el usuario kube"
$SSH "kube@${CP}" 'mkdir -p ~/.kube && cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && chmod 600 ~/.kube/config'

TOKEN=$($SSH "kube@${CP}" "sudo cat /var/lib/rancher/k3s/server/node-token")

for i in $(seq 1 "$WORKERS"); do
  ip="10.10.10.1${i}"
  if $SSH "kube@${ip}" "systemctl is-active --quiet k3s-agent"; then
    echo ">> k8s-w${i} ya pertenece al clúster"
  else
    echo ">> Uniendo k8s-w${i} (${ip})"
    $SSH "kube@${ip}" "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable K3S_URL=https://${CP}:6443 K3S_TOKEN=${TOKEN} sh -s - agent --node-ip ${ip}"
  fi
done

echo ">> Esperando nodos y poniendo el rol worker"
for i in $(seq 1 "$WORKERS"); do
  until $SSH "kube@${CP}" "kubectl get node k8s-w${i}" >/dev/null 2>&1; do sleep 5; done
  $SSH "kube@${CP}" "kubectl label node k8s-w${i} node-role.kubernetes.io/worker=worker --overwrite" >/dev/null
done
$SSH "kube@${CP}" "kubectl wait --for=condition=Ready node --all --timeout=300s && kubectl get nodes -o wide"
