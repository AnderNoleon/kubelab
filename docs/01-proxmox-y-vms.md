# 1. Proxmox y máquinas virtuales (INF-01, INF-02, INF-03)

## Inventario de nodos

| VM ID | Nombre | Rol | IP | vCPU | RAM | Disco | Sistema |
|---|---|---|---|---|---|---|---|
| 110 | k8s-cp | control plane | 10.10.10.10 | 2 | 1.25 GB | 25 GB | Ubuntu 24.04 (cloud image) + k3s |
| 111 | k8s-w1 | worker | 10.10.10.11 | 2 | 1.5 GB | 25 GB | Ubuntu 24.04 (cloud image) + k3s |
| 112 | k8s-w2 | worker | 10.10.10.12 | 2 | 1.5 GB | 25 GB | Ubuntu 24.04 (cloud image) + k3s |
| 9000 | ubuntu-2404-plantilla | plantilla cloud-init | — | 2 | — | — | Ubuntu 24.04 (cloud image) |

Host físico: Intel Core i5-3470S (4 núcleos, 2.9 GHz), 5.66 GB de RAM, disco de **COMPLETAR** GB · Proxmox VE 9.2 · hostname `proxmox.grupo7.lab` · IP `192.168.101.50` (cable, `vmbr0`).

Por la RAM disponible se usan 2 workers (acordado con el docente). Con 1 solo worker: `WORKERS=1 RAM_WORKER=2560`. Si el host tuviera más RAM, se puede subir `RAM_WORKER`.

## 1.1 Instalar Proxmox VE (INF-01)

1. Grabar la ISO de Proxmox VE 9.2 en una USB (balenaEtcher o Rufus en modo DD).
2. En la BIOS: activar la virtualización (VT-x/AMD-V) y arrancar desde la USB.
3. **Install Proxmox VE (Graphical)**, disco completo, zona horaria America/Guatemala, hostname `proxmox.grupo7.lab`.
4. Red de instalación: la tarjeta cableada (o un celular con *USB tethering*, porque el instalador no configura WiFi).
5. Repositorios: **Datacenter → proxmox → Updates → Repositories**: desactivar `enterprise`, agregar `No-Subscription`, y `apt update && apt full-upgrade -y`.
6. Si el host sale a Internet por WiFi: `apt install wpasupplicant iw` y agregar a `/etc/network/interfaces`:

   ```
   auto wlp2s0
   iface wlp2s0 inet dhcp
           wpa-ssid "RED"
           wpa-psk  "CLAVE"
   ```

7. Fijar la IP del host en la red del grupo (reserva DHCP en el router) y entrar a `https://IP:8006`.

## 1.2 Red del laboratorio

El clúster vive en una red interna con NAT. Así no ocupa IPs de la red del grupo y funciona igual con cable o WiFi:

```bash
bash scripts/proxmox/red-proxmox.sh vmbr0      # interfaz con Internet (cable). Por WiFi sería p. ej. wlp3s0
bash scripts/proxmox/publicar-servicios.sh     # reenvía los puertos 80 y 5432 de Proxmox a Traefik
```

Crea `vmbr1` con la IP `10.10.10.1/24` (la puerta de enlace de los nodos) y la regla de NAT.

## 1.3 Servidor NFS para el almacenamiento persistente

```bash
bash scripts/proxmox/servidor-nfs.sh
```

Exporta `/srv/nfs/kubelab` a `10.10.10.0/24`. Lo usa el aprovisionador `nfs-subdir-external-provisioner` (ver `docs/06-observabilidad-y-ha.md`).

## 1.4 Plantilla con cloud-init y clonación de los nodos (INF-02, INF-03)

En la Shell de Proxmox, con el repo clonado (`apt install git && git clone <repo>`):

```bash
bash scripts/proxmox/crear-vms.sh
# opcional: WORKERS=1 RAM_WORKER=2560  STORAGE=local-zfs  CLAVE_VM=algo
```

Qué hace, paso a paso (equivalente a hacerlo en la interfaz web):

1. Genera una llave SSH en el host (`/root/.ssh/id_ed25519`).
2. Descarga la imagen `noble-server-cloudimg-amd64.img` (Ubuntu 24.04 lista para cloud-init).
3. Crea la VM 9000: CPU tipo `host`, 2 núcleos, red VirtIO en `vmbr1`, controlador VirtIO SCSI, consola serial.
4. Importa la imagen como disco `scsi0` y agrega el disco de cloud-init (`ide2`).
5. Configura cloud-init: usuario `kube`, llave SSH del host, DNS `8.8.8.8`, dominio `grupo7.lab`.
6. La convierte en plantilla.
7. Por cada nodo: **Full Clone**, RAM según la tabla, IP fija con `ipconfig0` (gateway 10.10.10.1), arranque automático, disco ampliado a 25 GB y encendido.
8. Espera a que todos respondan por SSH.

El hostname de cada VM lo pone cloud-init con el nombre de la VM. Comprobar: `ssh kube@10.10.10.11 hostname`.

## 1.5 Preparar los nodos

```bash
bash scripts/proxmox/preparar-nodos.sh
```

Ejecuta `scripts/nodos/preparar-nodo.sh` en los 3 nodos: desactiva swap, instala `nfs-common` (para los volúmenes NFS) y registra los nombres de los nodos. k3s trae su propio containerd, así que no hace falta instalarlo aparte.
