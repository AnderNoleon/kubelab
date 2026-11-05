#!/usr/bin/env bash
# Servidor NFS en el host Proxmox para el almacenamiento persistente del clúster (PER-01).
# Ejecutar en la Shell de Proxmox como root:   bash servidor-nfs.sh
set -euo pipefail

CARPETA=/srv/nfs/kubelab
RED=10.10.10.0/24

apt-get update
apt-get install -y nfs-kernel-server

mkdir -p "$CARPETA"
chmod 777 "$CARPETA"

# no_root_squash: PostgreSQL necesita cambiar el dueño de su carpeta de datos
LINEA="$CARPETA $RED(rw,sync,no_subtree_check,no_root_squash)"
grep -qF "$CARPETA " /etc/exports || echo "$LINEA" >> /etc/exports

exportfs -ra
systemctl enable --now nfs-server
exportfs -v
echo "Listo: NFS exportando $CARPETA a $RED"
