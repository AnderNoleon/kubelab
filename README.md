# KubeLab · Grupo 7

Plataforma Kubernetes sobre Proxmox con GitOps: clúster kubeadm de 4 nodos, una API y una web de inventario con PostgreSQL, despliegue automático con GitHub Actions y Argo CD, observabilidad con Prometheus, Loki, Promtail y Grafana, y secretos gestionados en Doppler.

Integrantes: **COMPLETAR** · Docente: **COMPLETAR** (colaborador del repositorio)

## URLs (ACC-04)

Requisitos: estar conectado a la VPN (Tailscale) y tener [`docs/hosts.txt`](docs/hosts.txt) en el archivo hosts. Ver [docs/03-red-metallb-vpn.md](docs/03-red-metallb-vpn.md).

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

Las credenciales de solo lectura (base de datos, Grafana y Argo CD) se entregan al docente por un canal privado (ACC-03).

## Arquitectura

Ver [docs/arquitectura.md](docs/arquitectura.md) (diagrama y tabla de componentes).

```
Computadora física ── Proxmox VE 9.2 ── red 10.10.10.0/24 (vmbr1, NAT) ── NFS + Tailscale en el host
   ├── k8s-cp  10.10.10.10   control plane
   ├── k8s-w1  10.10.10.11   worker
   ├── k8s-w2  10.10.10.12   worker
   └── k8s-w3  10.10.10.13   worker
MetalLB 10.10.10.200 → Traefik → app / api / db / grafana / prometheus / argocd .grupo7.lab
GitHub (código + manifiestos) → Actions → Docker Hub (:hash) → commit del tag → Argo CD → clúster
Doppler (kubelab/prd) → Doppler Operator → Secrets · Doppler → GitHub Actions
```

## Inventario de nodos

| Nombre | IP | vCPU | RAM | Disco | Rol |
|---|---|---|---|---|---|
| k8s-cp | 10.10.10.10 | 2 | 4 GB | 40 GB | control plane |
| k8s-w1 | 10.10.10.11 | 2 | 4 GB | 40 GB | worker |
| k8s-w2 | 10.10.10.12 | 2 | 4 GB | 40 GB | worker |
| k8s-w3 | 10.10.10.13 | 2 | 4 GB | 40 GB | worker |

Pool de MetalLB reservado: `10.10.10.200-10.10.10.220`. Creación de las VMs paso a paso en [docs/01-proxmox-y-vms.md](docs/01-proxmox-y-vms.md).

## Reconstruir el entorno desde cero

| # | Paso | Dónde | Comando / documento |
|---|---|---|---|
| 1 | Instalar Proxmox VE | computadora física | [docs/01](docs/01-proxmox-y-vms.md#11-instalar-proxmox-ve-inf-01) |
| 2 | Red del laboratorio y NFS | Shell de Proxmox | `bash scripts/proxmox/red-proxmox.sh wlp2s0` · `bash scripts/proxmox/servidor-nfs.sh` |
| 3 | Crear las 4 VMs (cloud-init) | Shell de Proxmox | `bash scripts/proxmox/crear-vms.sh` |
| 4 | Preparar los nodos | Shell de Proxmox | `bash scripts/proxmox/preparar-nodos.sh` |
| 5 | Crear el clúster | Shell de Proxmox | `bash scripts/proxmox/instalar-kubernetes.sh` ([docs/02](docs/02-cluster-kubernetes.md)) |
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
scripts/               proxmox/ (red, NFS, VMs, kubeadm) · nodos/ (preparar nodo, arranque) · configurar.sh
docs/                  01–06 paso a paso, arquitectura, hosts.txt, ia.md, evidencias/
```

## Cumplimiento del enunciado

| Código | Cómo se cumple |
|---|---|
| INF-01..06 | Proxmox VE 9.2, 4 VMs desde plantilla cloud-init, IPs fijas, kubeadm, taint del control plane, pool de MetalLB reservado |
| APP-01..07 | CRUD + /health + /metrics, web CRUD, PostgreSQL StatefulSet con PVC, Dockerfiles, tag = hash, todo en YAML/Kustomize/Helm, Job db-init |
| NET-01..05 | MetalLB L2, Traefik LoadBalancer 10.10.10.200, IngressRoute por servicio, IngressRouteTCP para la base, dominios `*.grupo7.lab` |
| OBS-01..04 | Prometheus (nodos, Kubernetes, API), Loki + Promtail DaemonSet, Grafana con provisioning, dashboard versionado |
| HA-01..05 | HPA 2–6 por CPU, requests/limits/probes, PDB, metrics-server, k6 |
| PER-01..03 | NFS provisioner + StorageClass por defecto, PVC en Prometheus, Loki, Grafana y PostgreSQL, StatefulSet |
| CD-01..04 | Un workflow por app con filtro de ruta, Argo CD con IngressRoute, app of apps, prune + selfHeal |
| SEC-01..04 | Doppler `kubelab/prd`, operator + DopplerSecret, CLI de Doppler en Actions, solo tokens de Doppler a mano |
| ACC-01..04 | `docs/hosts.txt`, Tailscale, usuarios de solo lectura fuera del repo, esta tabla de URLs |

## Trabajo en equipo

Ramas y pull requests hacia `main`, commits con [Conventional Commits](https://www.conventionalcommits.org/es/) (`feat`, `fix`, `chore`, `docs`, `ci`), sin push forzado. El uso de IA está declarado en [docs/ia.md](docs/ia.md).
