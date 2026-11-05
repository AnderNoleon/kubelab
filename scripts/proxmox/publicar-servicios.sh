#!/usr/bin/env bash
# Publica los servicios del clúster en la IP de Proxmox (la de la red donde se conectan las computadoras).
# Todo lo que llegue a Proxmox por el puerto 80 (web) o 5432 (PostgreSQL) se reenvía a Traefik
# (10.10.10.200, IP de MetalLB). Así, en el archivo hosts basta con poner la IP de Proxmox:
#   192.168.101.50  app.grupo7.lab  grafana.grupo7.lab ...
# Traefik decide a qué servicio va cada petición por el nombre de dominio.
#
# Ejecutar en la Shell de Proxmox como root:   bash scripts/proxmox/publicar-servicios.sh
# Queda como servicio de systemd, así que se aplica solo en cada arranque.
set -euo pipefail

cat > /usr/local/sbin/kubelab-publicar.sh <<'EOF'
#!/usr/bin/env bash
# Reenvío de puertos de Proxmox hacia Traefik (KubeLab grupo 7)
TRAEFIK=10.10.10.200
for puerto in 80 5432; do
  # Solo tráfico dirigido a una IP del propio Proxmox y que no venga de la red del clúster
  regla="-p tcp --dport ${puerto} -m addrtype --dst-type LOCAL ! -i vmbr1 -j DNAT --to-destination ${TRAEFIK}:${puerto}"
  iptables -t nat -C PREROUTING $regla 2>/dev/null || iptables -t nat -A PREROUTING $regla
done
EOF
chmod +x /usr/local/sbin/kubelab-publicar.sh

cat > /etc/systemd/system/kubelab-publicar.service <<'EOF'
[Unit]
Description=KubeLab: reenvío de puertos 80 y 5432 hacia Traefik
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/kubelab-publicar.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kubelab-publicar.service
iptables -t nat -S PREROUTING | grep 10.10.10.200
echo "Listo. En el archivo hosts de cada computadora, los dominios *.grupo7.lab apuntan a la IP de Proxmox."
