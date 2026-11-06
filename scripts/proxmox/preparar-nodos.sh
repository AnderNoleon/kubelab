#!/usr/bin/env bash
# Desde el host Proxmox: copia y ejecuta scripts/nodos/preparar-nodo.sh en todos los nodos, en paralelo.
# Uso (en la carpeta del repo clonado en Proxmox):   bash scripts/proxmox/preparar-nodos.sh
# Con otra cantidad de workers:                      WORKERS=1 bash scripts/proxmox/preparar-nodos.sh
# Un solo nodo (solo k8s-cp):                        WORKERS=0 bash scripts/proxmox/preparar-nodos.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

WORKERS="${WORKERS:-2}"
[[ "$WORKERS" =~ ^[0-3]$ ]] || { echo "WORKERS debe ser 0, 1, 2 o 3"; exit 1; }
IPS="10.10.10.10"
for i in $(seq 1 "$WORKERS"); do IPS="$IPS 10.10.10.1${i}"; done

for ip in $IPS; do
  (
    scp -q scripts/nodos/preparar-nodo.sh "kube@${ip}:/tmp/preparar-nodo.sh"
    ssh "kube@${ip}" "sudo bash /tmp/preparar-nodo.sh" > "/tmp/preparar-${ip}.log" 2>&1 \
      && echo "OK    ${ip}" || echo "ERROR ${ip} (ver /tmp/preparar-${ip}.log)"
  ) &
done
wait
