# 3. Red, MetalLB, Traefik y VPN (INF-06, NET-01 a NET-05, ACC-01, ACC-02)

## Direccionamiento

| Rango / IP | Uso |
|---|---|
| 10.10.10.0/24 | Red del laboratorio (bridge `vmbr1` en Proxmox) |
| 10.10.10.1 | Host Proxmox: puerta de enlace, NAT, NFS y router de Tailscale |
| 10.10.10.10 – 10.10.10.13 | Nodos del clúster |
| 10.10.10.200 – 10.10.10.220 | **Reservado para MetalLB** (INF-06). Ninguna VM usa estas IPs |
| 10.10.10.200 | Traefik: todas las URLs del grupo y PostgreSQL (puerto 5432) |

## MetalLB en capa 2 (NET-01)

`k8s/platform/metallb/config/pool.yaml` define el `IPAddressPool` `pool-grupo7` y el `L2Advertisement` `l2-grupo7`. En capa 2, el nodo que tiene la IP responde las consultas ARP de la red.

## Traefik (NET-02, NET-03, NET-04)

- Service `LoadBalancer` con IP fija por la anotación `metallb.io/loadBalancerIPs: 10.10.10.200` (`k8s/platform/traefik/values.yaml`).
- Entrypoints: `web` (puerto 80) y `postgres` (puerto 5432, TCP).
- Una `IngressRoute` por servicio web, cada una junto a su servicio:

| Dominio | Recurso | Archivo |
|---|---|---|
| app.grupo7.lab | IngressRoute | `k8s/apps/web/ingressroute.yaml` |
| api.grupo7.lab | IngressRoute | `k8s/apps/api/ingressroute.yaml` |
| db.grupo7.lab:5432 | IngressRouteTCP | `k8s/apps/database/ingressroutetcp.yaml` |
| grafana.grupo7.lab | IngressRoute | `k8s/observability/grafana/manifests/ingressroute.yaml` |
| prometheus.grupo7.lab | IngressRoute | `k8s/observability/prometheus/manifests/ingressroute.yaml` |
| argocd.grupo7.lab | IngressRoute | `k8s/argocd/ingress/ingressroute.yaml` |

Verificación desde un nodo: `kubectl get svc -n traefik` (EXTERNAL-IP `10.10.10.200`) y `curl -H "Host: api.grupo7.lab" http://10.10.10.200/health`.

## VPN con Tailscale (ACC-02)

El host Proxmox funciona como *subnet router*: anuncia la red `10.10.10.0/24` a la red privada de Tailscale del grupo. El plan gratuito Personal admite hasta 6 usuarios.

### Configuración en Proxmox (una vez)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --advertise-routes=10.10.10.0/24 --accept-dns=false
```

1. Abrir el enlace que imprime e iniciar sesión con la cuenta del grupo.
2. En https://login.tailscale.com/admin/machines → la máquina `pve` → **Edit route settings** → aprobar `10.10.10.0/24`.
3. En la misma máquina: **Disable key expiry**, para que no se desconecte durante la revisión.

### Cómo se une el docente

1. El grupo lo invita: **admin console → Users → Invite users** (por correo).
2. El docente acepta la invitación, instala Tailscale (https://tailscale.com/download) e inicia sesión con esa cuenta.
3. Windows y macOS aceptan la ruta automáticamente. En Linux: `sudo tailscale up --accept-routes`.
4. Copia `docs/hosts.txt` al final de su archivo hosts:
   - Windows: `C:\Windows\System32\drivers\etc\hosts` (Bloc de notas como administrador)
   - Linux/macOS: `/etc/hosts`
5. Prueba: `ping 10.10.10.10` y luego abrir http://app.grupo7.lab.
