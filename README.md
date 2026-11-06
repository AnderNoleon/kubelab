# KubeLab · Grupo 7

Plataforma Kubernetes sobre Proxmox con GitOps: clúster k3s de un solo nodo, una API y una web de inventario con PostgreSQL, despliegue automático con GitHub Actions y Argo CD, observabilidad con Prometheus, Loki, Promtail y Grafana, y secretos gestionados en Doppler.

Integrantes: **Anderson** y **Dennys** · Docente: **COMPLETAR** (colaborador del repositorio)

## URLs (ACC-04)

Requisitos: estar en la misma red que Proxmox (`192.168.101.50`) y tener [`docs/hosts.txt`](docs/hosts.txt) en el archivo hosts. Desde fuera de esa red se entra con la VPN (Tailscale). Ver [docs/03-red-metallb-vpn.md](docs/03-red-metallb-vpn.md).

| URL | Servicio | Qué se debe ver |
|---|---|---|
| http://app.grupo7.lab | Web (nginx) | Inventario de productos: listar, agregar, editar y eliminar. En el encabezado, la versión (hash) de la web y de la API |
| http://api.grupo7.lab/productos | API (Node.js) | JSON con la lista de productos |
| http://api.grupo7.lab/health | API | `{"status":"ok","version":"<hash>"}` |
| http://api.grupo7.lab/metrics | API | Métricas en formato Prometheus (`http_requests_total`, ...) |
| `db.grupo7.lab:5432` | PostgreSQL 17 | Conexión con un cliente SQL (DBeaver, psql), base `kubelab`, usuario de solo lectura |
| http://grafana.grupo7.lab | Grafana | Dashboard **KubeLab · Grupo 7**: CPU, memoria, réplicas, peticiones por segundo y logs |
| http://prometheus.grupo7.lab | Prometheus | Status → Targets: nodos, kube-state-metrics y la API en `UP` |
| http://argocd.grupo7.lab | Argo CD | 18 Applications (root + 17) en `Synced` y `Healthy` |

![Web de inventario en app.grupo7.lab](imagenes/WhatsApp%20Image%202026-11-05%20at%209.33.57%20PM.jpeg)
*http://app.grupo7.lab con la lista de productos; en el encabezado, la versión `5e46bde` de la web y de la API.*

Las credenciales de solo lectura (base de datos, Grafana y Argo CD) se entregan al docente por un canal privado (ACC-03).

## Arquitectura

Ver [docs/arquitectura.md](docs/arquitectura.md) (diagrama y tabla de componentes).

```
Computadora física (192.168.101.50) ── Proxmox VE 9.2 ── red 10.10.10.0/24 (vmbr1, NAT) ── NFS + Tailscale en el host
   └── k8s-cp  10.10.10.10   control plane + cargas (k3s server, sin taint)
Navegador → 192.168.101.50:80/5432 (DNAT) → MetalLB 10.10.10.200 → Traefik → app / api / db / grafana / prometheus / argocd .grupo7.lab
GitHub (código + manifiestos) → Actions → Docker Hub (:hash) → commit del tag → Argo CD → clúster
Doppler (kubelab/prd) → Doppler Operator → Secrets · Doppler → GitHub Actions
```

## Inventario de nodos

| Nombre | IP | vCPU | RAM | Disco | Rol |
|---|---|---|---|---|---|
| k8s-cp | 10.10.10.10 | 2 | 4 GB | 25 GB | control plane + cargas |

Host: Intel i5-3470S (4 núcleos), 5.66 GB de RAM, Proxmox VE 9.2, `proxmox.grupo7.lab` (192.168.101.50). Por la RAM del host, el clúster es de un solo nodo con k3s, como se acordó con el docente (ver [docs/02](docs/02-cluster-kubernetes.md#clúster-de-un-solo-nodo)).

Pool de MetalLB reservado: `10.10.10.200-10.10.10.220`. Creación de la VM paso a paso en [docs/01-proxmox-y-vms.md](docs/01-proxmox-y-vms.md).

## Reconstruir el entorno desde cero

| # | Paso | Dónde | Comando / documento |
|---|---|---|---|
| 1 | Instalar Proxmox VE | computadora física | [docs/01](docs/01-proxmox-y-vms.md#11-instalar-proxmox-ve-inf-01) |
| 2 | Red, reenvío de puertos y NFS | Shell de Proxmox | `bash scripts/proxmox/red-proxmox.sh vmbr0` · `bash scripts/proxmox/publicar-servicios.sh` · `bash scripts/proxmox/servidor-nfs.sh` |
| 3 | Crear la VM (cloud-init) | Shell de Proxmox | `WORKERS=0 RAM_CP=4096 bash scripts/proxmox/crear-vms.sh` |
| 4 | Preparar el nodo | Shell de Proxmox | `WORKERS=0 bash scripts/proxmox/preparar-nodos.sh` |
| 5 | Crear el clúster k3s | Shell de Proxmox | `WORKERS=0 bash scripts/proxmox/instalar-kubernetes.sh` ([docs/02](docs/02-cluster-kubernetes.md)) |
| 6 | VPN | Shell de Proxmox | Tailscale como subnet router ([docs/03](docs/03-red-metallb-vpn.md)) |
| 7 | Secretos en Doppler y GitHub | navegador | [docs/05](docs/05-secretos-doppler.md) |
| 8 | Primer build de las imágenes | GitHub → Actions | ejecutar `api` y `web` con **Run workflow** |
| 9 | Arranque de GitOps | k8s-cp | `bash scripts/nodos/arranque-argocd.sh` ([docs/04](docs/04-gitops-cicd.md)) |
| 10 | Verificar | laptop con VPN | tabla de URLs de arriba |

## Estructura del repositorio

```
apps/
  api/                 API Node.js 22: CRUD /productos, /health, /ready, /metrics · Dockerfile · pruebas
  web/                 HTML + JS servido por nginx sin root · Dockerfile · prueba de humo
k8s/
  apps/                api, web y database (StatefulSet, Job de esquema, IngressRouteTCP)
  platform/            namespaces, MetalLB, Traefik, NFS (StorageClass), metrics-server, Doppler
  observability/       Prometheus, Loki, Promtail, Grafana (+ dashboard JSON)
  argocd/              install (Argo CD con kustomize), ingress, root.yaml y apps/ (app of apps)
.github/workflows/     api.yml, web.yml y _build-deploy.yml (reutilizable)
loadtest/              k6-carga.js (prueba del HPA)
scripts/               proxmox/ (red, reenvío de puertos, NFS, VMs, k3s) · nodos/ (preparar nodo, arranque) · configurar.sh
docs/                  01–06 paso a paso, arquitectura, hosts.txt, ia.md, evidencias/
imagenes/              capturas del proceso, usadas en los documentos (índice en docs/evidencias/README.md)
```

## Cumplimiento del enunciado

| Código | Cómo se cumple |
|---|---|
| INF-01..06 | Proxmox VE 9.2, VM desde plantilla cloud-init, IP fija, k3s, un solo nodo por recursos del host (acordado con el docente), pool de MetalLB reservado |
| APP-01..07 | CRUD + /health + /metrics, web CRUD, PostgreSQL StatefulSet con PVC, Dockerfiles, tag = hash, todo en YAML/Kustomize/Helm, Job db-init |
| NET-01..05 | MetalLB L2, Traefik LoadBalancer 10.10.10.200, IngressRoute por servicio, IngressRouteTCP para la base, dominios `*.grupo7.lab` |
| OBS-01..04 | Prometheus (nodos, Kubernetes, API), Loki + Promtail DaemonSet, Grafana con provisioning, dashboard versionado |
| HA-01..05 | HPA 2–6 por CPU, requests/limits/probes, PDB, metrics-server, k6 |
| PER-01..03 | NFS provisioner + StorageClass por defecto, PVC en Prometheus, Loki, Grafana y PostgreSQL, StatefulSet |
| CD-01..04 | Un workflow por app con filtro de ruta, Argo CD con IngressRoute, app of apps, prune + selfHeal |
| SEC-01..04 | Doppler `kubelab/prd`, operator + DopplerSecret, CLI de Doppler en Actions, solo tokens de Doppler a mano |
| ACC-01..04 | `docs/hosts.txt` (IP de Proxmox + reenvío de puertos), Tailscale, usuarios de solo lectura fuera del repo, esta tabla de URLs |

## Trabajo en equipo

Ramas y pull requests hacia `main`, commits con [Conventional Commits](https://www.conventionalcommits.org/es/) (`feat`, `fix`, `chore`, `docs`, `ci`), sin push forzado. El uso de IA está declarado en [docs/ia.md](docs/ia.md).
