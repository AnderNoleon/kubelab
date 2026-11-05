#!/usr/bin/env bash
# Desde el host Proxmox: copia y ejecuta scripts/nodos/preparar-nodo.sh en los 4 nodos, en paralelo.
# Uso (en la carpeta del repo clonado en Proxmox):   bash scripts/proxmox/preparar-nodos.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

for ip in 10.10.10.10 10.10.10.11 10.10.10.12 10.10.10.13; do
  (
    scp -q scripts/nodos/preparar-nodo.sh "kube@${ip}:/tmp/preparar-nodo.sh"
    ssh "kube@${ip}" "sudo bash /tmp/preparar-nodo.sh" > "/tmp/preparar-${ip}.log" 2>&1 \
      && echo "OK    ${ip}" || echo "ERROR ${ip} (ver /tmp/preparar-${ip}.log)"
  ) &
done
wait
tail -n 1 /tmp/preparar-10.10.10.*.log
