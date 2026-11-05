# 1. Proxmox y máquinas virtuales (INF-01, INF-02, INF-03)

## Inventario de nodos

| VM ID | Nombre | Rol | IP | vCPU | RAM | Disco | Sistema |
|---|---|---|---|---|---|---|---|
| 110 | k8s-cp | control plane | 10.10.10.10 | 2 | 4 GB | 40 GB | Ubuntu 24.04 (cloud image) |
| 111 | k8s-w1 | worker | 10.10.10.11 | 2 | 4 GB | 40 GB | Ubuntu 24.04 (cloud image) |
| 112 | k8s-w2 | worker | 10.10.10.12 | 2 | 4 GB | 40 GB | Ubuntu 24.04 (cloud image) |
| 113 | k8s-w3 | worker | 10.10.10.13 | 2 | 4 GB | 40 GB | Ubuntu 24.04 (cloud image) |
| 9000 | ubuntu-2404-plantilla | plantilla cloud-init | — | 2 | — | — | Ubuntu 24.04 (cloud image) |

Si el host tiene 16 GB de RAM, usen `RAM_WORKER=3072` al crear las VMs.

Host físico: **COMPLETAR** (modelo, CPU, RAM, disco) · Proxmox VE 9.2 · IP en la red del grupo: **COMPLETAR**.

## 1.1 Instalar Proxmox VE (INF-01)

1. Grabar la ISO de Proxmox VE 9.2 en una USB (balenaEtcher o Rufus en modo DD).
2. En la BIOS: activar la virtualización (VT-x/AMD-V) y arrancar desde la USB.
3. **Install Proxmox VE (Graphical)**, disco completo, zona horaria America/Guatemala, hostname `pve.grupo7.lab`.
4. Red de instalación: la tarjeta cableada (o un celular con *USB tethering*, porque el instalador no configura WiFi).
5. Repositorios: **Datacenter → pve → Updates → Repositories**: desactivar `enterprise`, agregar `No-Subscription`, y `apt update && apt full-upgrade -y`.
6. Si el host sale a Internet por WiFi: `apt install wpasupplicant iw` y agregar a `/etc/network/interfaces`:

   ```
   auto wlp2s0
   iface wlp2s0 inet dhcp
           wpa-ssid "RED"
           wpa-psk  "CLAVE"
   ```

7. Fijar la IP del host en la red del grupo (reserva DHCP en el router) y entrar a `https://IP:8006`.

## 1.2 Red del laboratorio

Una tarjeta WiFi no puede ser puente (bridge) de VMs, así que el clúster vive en una red interna con NAT:

```bash
bash scripts/proxmox/red-proxmox.sh wlp2s0     # o vmbr0 si el host está por cable
```

Crea `vmbr1` con la IP `10.10.10.1/24` (la puerta de enlace de los nodos) y la regla de NAT.

## 1.3 Servidor NFS para el almacenamiento persistente

```bash
bash scripts/proxmox/servidor-nfs.sh
```

Exporta `/srv/nfs/kubelab` a `10.10.10.0/24`. Lo usa el aprovisionador `nfs-subdir-external-provisioner` (ver `docs/06-observabilidad-y-ha.md`).

## 1.4 Plantilla con cloud-init y clonación de los 4 nodos (INF-02, INF-03)

En la Shell de Proxmox, con el repo clonado (`apt install git && git clone <repo>`):

```bash
bash scripts/proxmox/crear-vms.sh
# opcional: STORAGE=local-zfs RAM_WORKER=3072 CLAVE_VM=algo bash scripts/proxmox/crear-vms.sh
```

Qué hace, paso a paso (equivalente a hacerlo en la interfaz web):

1. Genera una llave SSH en el host (`/root/.ssh/id_ed25519`).
2. Descarga la imagen `noble-server-cloudimg-amd64.img` (Ubuntu 24.04 lista para cloud-init).
3. Crea la VM 9000: CPU tipo `host`, 2 núcleos, red VirtIO en `vmbr1`, controlador VirtIO SCSI, consola serial.
4. Importa la imagen como disco `scsi0` y agrega el disco de cloud-init (`ide2`).
5. Configura cloud-init: usuario `kube`, llave SSH del host, DNS `8.8.8.8`, dominio `grupo7.lab`.
6. La convierte en plantilla.
7. Por cada nodo: **Full Clone**, RAM según la tabla, IP fija con `ipconfig0` (gateway 10.10.10.1), arranque automático, disco ampliado a 40 GB y encendido.
8. Espera a que los 4 respondan por SSH.

El hostname de cada VM lo pone cloud-init con el nombre de la VM. Comprobar: `ssh kube@10.10.10.11 hostname`.

## 1.5 Preparar los nodos

```bash
bash scripts/proxmox/preparar-nodos.sh
```

Ejecuta `scripts/nodos/preparar-nodo.sh` en los 4 nodos: desactiva swap, carga `overlay` y `br_netfilter`, instala containerd (cgroup systemd), `nfs-common`, y kubeadm/kubelet/kubectl v1.36.
