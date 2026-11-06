# 1. Proxmox y máquinas virtuales (INF-01, INF-02, INF-03)

## Inventario de nodos

| VM ID | Nombre | Rol | IP | vCPU | RAM | Disco | Sistema |
|---|---|---|---|---|---|---|---|
| 110 | k8s-cp | control plane + cargas | 10.10.10.10 | 2 | 4 GB | 25 GB | Ubuntu 24.04 (cloud image) + k3s |
| 9000 | ubuntu-2404-plantilla | plantilla cloud-init | — | 2 | — | — | Ubuntu 24.04 (cloud image) |

Host físico: Intel Core i5-3470S (4 núcleos, 2.9 GHz), 5.66 GB de RAM, disco de **COMPLETAR** GB · Proxmox VE 9.2 · hostname `proxmox.grupo7.lab` · IP `192.168.101.50` (cable, `vmbr0`).

Por la RAM del host (5.66 GB, de los que Proxmox usa cerca de 1.5 GB), el clúster quedó en **un solo nodo**, `k8s-cp`, que es control plane y además ejecuta todas las cargas (acordado con el docente; ver [docs/02](02-cluster-kubernetes.md#clúster-de-un-solo-nodo)). Los scripts siguen aceptando workers (`WORKERS=1..3`) por si se dispone de un host con más memoria.

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
WORKERS=0 RAM_CP=4096 bash scripts/proxmox/crear-vms.sh
# opcional: STORAGE=local-zfs  CLAVE_VM=algo
# con más RAM en el host: WORKERS=2 (agrega k8s-w1 y k8s-w2 con RAM_WORKER MB cada uno)
```

Qué hace, paso a paso (equivalente a hacerlo en la interfaz web):

1. Genera una llave SSH en el host (`/root/.ssh/id_ed25519`).
2. Descarga la imagen `noble-server-cloudimg-amd64.img` (Ubuntu 24.04 lista para cloud-init).
3. Crea la VM 9000: CPU tipo `host`, 2 núcleos, red VirtIO en `vmbr1`, controlador VirtIO SCSI, consola serial.
4. Importa la imagen como disco `scsi0` y agrega el disco de cloud-init (`ide2`).
5. Configura cloud-init: usuario `kube`, llave SSH del host, DNS `8.8.8.8`, dominio `grupo7.lab`.
6. La convierte en plantilla.
7. Por cada nodo (con `WORKERS=0`, solo `k8s-cp`): **Full Clone**, RAM según la tabla, IP fija con `ipconfig0` (gateway 10.10.10.1), arranque automático, disco ampliado a 25 GB y encendido.
8. Espera a que el nodo responda por SSH.

El hostname de cada VM lo pone cloud-init con el nombre de la VM. Comprobar: `ssh kube@10.10.10.10 hostname`.

## 1.5 Preparar los nodos

```bash
WORKERS=0 bash scripts/proxmox/preparar-nodos.sh
```

Ejecuta `scripts/nodos/preparar-nodo.sh` en el nodo (y en los workers, si los hay): desactiva swap, instala `nfs-common` (para los volúmenes NFS) y registra los nombres de los nodos. k3s trae su propio containerd, así que no hace falta instalarlo aparte.

Evidencia: [creación de las VMs con `crear-vms.sh` (primer intento, con workers)](../imagenes/WhatsApp%20Image%202026-11-04%20at%2011.50.02%20PM.jpeg).
