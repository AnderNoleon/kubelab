#!/usr/bin/env bash
# Crea la plantilla Ubuntu 24.04 con cloud-init y clona los nodos del clúster (INF-02, INF-03).
# Por defecto: 1 control plane + 2 workers (ajustado a un host de 6 GB de RAM).
# Ejecutar en la Shell de Proxmox como root:   bash scripts/proxmox/crear-vms.sh
# Variables opcionales:
#   WORKERS=2         cantidad de workers (1 a 3)
#   RAM_CP=1280       RAM del control plane en MB
#   RAM_WORKER=1536   RAM de cada worker en MB
#   DISCO=25G         tamaño de disco de cada nodo
#   STORAGE=local-lvm almacenamiento de Proxmox (local-zfs si se instaló con ZFS)
#   CLAVE_VM=algo     contraseña del usuario kube para la consola (opcional)
set -euo pipefail

STORAGE="${STORAGE:-local-lvm}"
WORKERS="${WORKERS:-2}"
BRIDGE=vmbr1
GATEWAY=10.10.10.1
DNS=8.8.8.8
USUARIO=kube
RAM_CP="${RAM_CP:-1280}"
RAM_WORKER="${RAM_WORKER:-1536}"
NUCLEOS=2
DISCO="${DISCO:-25G}"
PLANTILLA=9000
IMAGEN=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img
URL_IMAGEN=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

[[ "$WORKERS" =~ ^[1-3]$ ]] || { echo "WORKERS debe ser 1, 2 o 3"; exit 1; }

# Llave SSH del host Proxmox: con ella se entra a los nodos sin contraseña
[[ -f /root/.ssh/id_ed25519 ]] || ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519

if [[ ! -f "$IMAGEN" ]]; then
  echo ">> Descargando Ubuntu 24.04 cloud image"
  wget -O "$IMAGEN" "$URL_IMAGEN"
fi

if ! qm status "$PLANTILLA" >/dev/null 2>&1; then
  echo ">> Creando plantilla $PLANTILLA"
  qm create "$PLANTILLA" --name ubuntu-2404-plantilla --ostype l26 \
    --cpu host --cores "$NUCLEOS" --memory "$RAM_WORKER" \
    --net0 "virtio,bridge=${BRIDGE}" --scsihw virtio-scsi-pci \
    --serial0 socket --vga serial0
  qm set "$PLANTILLA" --scsi0 "${STORAGE}:0,import-from=${IMAGEN}"
  qm set "$PLANTILLA" --ide2 "${STORAGE}:cloudinit" --boot order=scsi0
  qm set "$PLANTILLA" --ciuser "$USUARIO" --sshkeys /root/.ssh/id_ed25519.pub \
    --nameserver "$DNS" --searchdomain grupo7.lab --ciupgrade 0
  if [[ -n "${CLAVE_VM:-}" ]]; then qm set "$PLANTILLA" --cipassword "$CLAVE_VM"; fi
  qm template "$PLANTILLA"
fi

crear() {
  local id=$1 nombre=$2 ip=$3 ram=$4
  if qm status "$id" >/dev/null 2>&1; then echo ">> $nombre ($id) ya existe"; return 0; fi
  echo ">> Clonando $nombre ($id) con IP $ip y ${ram} MB"
  qm clone "$PLANTILLA" "$id" --name "$nombre" --full
  qm set "$id" --memory "$ram" --cores "$NUCLEOS" \
    --ipconfig0 "ip=${ip}/24,gw=${GATEWAY}" --onboot 1
  qm resize "$id" scsi0 "$DISCO"
  qm start "$id"
}

IPS=(10.10.10.10)
crear 110 k8s-cp 10.10.10.10 "$RAM_CP"
for i in $(seq 1 "$WORKERS"); do
  crear $((110 + i)) "k8s-w${i}" "10.10.10.1${i}" "$RAM_WORKER"
  IPS+=("10.10.10.1${i}")
done

echo ">> Esperando SSH en los nodos"
for ip in "${IPS[@]}"; do
  until ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 "${USUARIO}@${ip}" true 2>/dev/null; do sleep 5; done
  echo "   $ip listo"
done
qm list
echo "Listo. Siguiente paso: WORKERS=${WORKERS} bash scripts/proxmox/preparar-nodos.sh"
