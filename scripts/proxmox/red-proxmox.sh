#!/usr/bin/env bash
# Crea la red del laboratorio en el host Proxmox: bridge vmbr1 (10.10.10.0/24) con salida a Internet por NAT.
# Ejecutar en la Shell de Proxmox como root:   bash red-proxmox.sh <interfaz-de-salida>
# La interfaz de salida es la que tiene Internet: la tarjeta WiFi (ej. wlp2s0) o vmbr0 si es por cable.
set -euo pipefail

SALIDA="${1:-}"
if [[ -z "$SALIDA" ]]; then
  echo "Uso: bash red-proxmox.sh <interfaz-de-salida>   (ver nombres con: ip -br a)"; exit 1
fi
ip link show "$SALIDA" >/dev/null || { echo "No existe la interfaz $SALIDA"; exit 1; }

if grep -q "^auto vmbr1" /etc/network/interfaces; then
  echo "vmbr1 ya existe en /etc/network/interfaces, no se modifica"
else
  cp /etc/network/interfaces "/etc/network/interfaces.bak.$(date +%s)"
  cat >> /etc/network/interfaces <<EOF

# --- KubeLab grupo 7: red del laboratorio ---
auto vmbr1
iface vmbr1 inet static
        address 10.10.10.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0
        post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up   iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o ${SALIDA} -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s 10.10.10.0/24 -o ${SALIDA} -j MASQUERADE
EOF
fi

ifreload -a
ip -br a show vmbr1
iptables -t nat -S POSTROUTING | grep MASQUERADE
echo "Listo: red 10.10.10.0/24 en vmbr1, con NAT hacia ${SALIDA}"
