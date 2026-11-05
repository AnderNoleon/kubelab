#!/usr/bin/env bash
# Crea la plantilla Ubuntu 24.04 con cloud-init y clona los 4 nodos del clúster (INF-02, INF-03).
# Ejecutar en la Shell de Proxmox como root:   bash crear-vms.sh
# Variables opcionales:  STORAGE=local-zfs  RAM_CP=4096  RAM_WORKER=4096  DISCO=40G  CLAVE_VM=algo
set -euo pipefail

STORAGE="${STORAGE:-local-lvm}"     # en instalaciones con ZFS suele ser local-zfs (ver Datacenter > Storage)
BRIDGE=vmbr1
GATEWAY=10.10.10.1
DNS=8.8.8.8
USUARIO=kube
RAM_CP="${RAM_CP:-4096}"
RAM_WORKER="${RAM_WORKER:-4096}"
NUCLEOS=2
DISCO="${DISCO:-40G}"
PLANTILLA=9000
IMAGEN=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img
URL_IMAGEN=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

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
  [[ -n "${CLAVE_VM:-}" ]] && qm set "$PLANTILLA" --cipassword "$CLAVE_VM"
  qm template "$PLANTILLA"
fi

crear() {
  local id=$1 nombre=$2 ip=$3 ram=$4
  if qm status "$id" >/dev/null 2>&1; then echo ">> $nombre ($id) ya existe"; return; fi
  echo ">> Clonando $nombre ($id) con IP $ip"
  qm clone "$PLANTILLA" "$id" --name "$nombre" --full
  qm set "$id" --memory "$ram" --cores "$NUCLEOS" \
    --ipconfig0 "ip=${ip}/24,gw=${GATEWAY}" --onboot 1
  qm resize "$id" scsi0 "$DISCO"
  qm start "$id"
}

crear 110 k8s-cp 10.10.10.10 "$RAM_CP"
crear 111 k8s-w1 10.10.10.11 "$RAM_WORKER"
crear 112 k8s-w2 10.10.10.12 "$RAM_WORKER"
crear 113 k8s-w3 10.10.10.13 "$RAM_WORKER"

echo ">> Esperando SSH en los nodos"
for ip in 10.10.10.10 10.10.10.11 10.10.10.12 10.10.10.13; do
  until ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 "${USUARIO}@${ip}" true 2>/dev/null; do sleep 5; done
  echo "   $ip listo"
done
qm list
echo "Listo. Siguiente paso: bash preparar-nodos.sh"
