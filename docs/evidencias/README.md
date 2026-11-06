# Evidencias

## Capturas pendientes

Guardar aquí las capturas y grabaciones con estos nombres:

| Archivo | Qué muestra |
|---|---|
| `01-nodos-ready.png` | `kubectl get nodes -o wide` con 1 nodo Ready (`k8s-cp`) |
| `02-proxmox-vms.png` | Proxmox con la VM del clúster encendida |
| `03-argocd-apps.png` | Argo CD con todas las Applications Synced y Healthy |
| `04-pipeline-api.png` | Run de GitHub Actions con el resumen "Imagen publicada" |
| `05-dockerhub-tags.png` | Docker Hub con las etiquetas por hash de commit |
| `06-commit-bot.png` | Commit `ci(api): desplegar imagen ...` que cambia `k8s/apps/api/deployment.yaml` |
| `07-despliegue-automatico.mp4` | Del push al pod nuevo: Actions → commit → Argo CD → web con la versión nueva |
| `08-escalado-hpa.mp4` | k6 corriendo y `kubectl get hpa -w` subiendo de 2 a más réplicas |
| `09-eliminar-pod.mp4` | Borrar un pod de la API mientras `curl` sigue respondiendo 200 |
| `10-selfheal.mp4` | Cambio manual revertido por Argo CD |
| `11-grafana-dashboard.png` | Dashboard KubeLab con métricas y logs |
| `12-prometheus-targets.png` | Targets UP, incluido el /metrics de la API |
| `13-persistencia.png` | Dato que sobrevive al borrar `postgres-0` |

## Capturas tomadas durante el montaje

Están en [`imagenes/`](../../imagenes/). Las de infraestructura son de los intentos con workers, antes de pasar a un solo nodo ([docs/02](../02-cluster-kubernetes.md#clúster-de-un-solo-nodo)).

### Infraestructura y clúster

| Captura | Qué muestra |
|---|---|
| [VMs creadas y nodos preparados](../../imagenes/WhatsApp%20Image%202026-11-04%20at%2011.50.02%20PM.jpeg) | `crear-vms.sh` y `preparar-nodos.sh` (primer intento: k8s-cp, k8s-w1, k8s-w2 y la plantilla 9000) |
| [k3s instalado](../../imagenes/WhatsApp%20Image%202026-11-04%20at%2011.57.43%20PM.jpeg) | `instalar-kubernetes.sh` terminando con los nodos `Ready` (primer intento, 3 nodos) |
| [Nodos desde k8s-cp](../../imagenes/WhatsApp%20Image%202026-11-04%20at%2011.59.28%20PM.jpeg) | `kubectl get nodes -o wide` en la consola de Proxmox (primer intento) |
| [Taint del control plane](../../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.00.33%20AM.jpeg) | `NoSchedule` en k8s-cp mientras había workers (luego se quitó) |
| [Segundo intento: se elimina k8s-w2](../../imagenes/WhatsApp%20Image%202026-11-05%20at%208.06.26%20PM.jpeg) | `kubectl delete node k8s-w2`; quedan k8s-cp y k8s-w1 |
| [RAM del host al 95 %](../../imagenes/WhatsApp%20Image%202026-11-05%20at%208.23.20%20PM.jpeg) | Resumen de Proxmox: 5.40 de 5.66 GiB usados, i5-3470S, Proxmox VE 9.2.2. Motivo del clúster de un solo nodo |
| [StorageClass y Traefik](../../imagenes/WhatsApp%20Image%202026-11-05%20at%208.08.52%20PM.jpeg) | `nfs-client (default)` y el Service de Traefik con `EXTERNAL-IP 10.10.10.200` |

### GitOps y CI/CD

| Captura | Qué muestra |
|---|---|
| [Pipeline de web](../../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.43.31%20AM.jpeg) | Run de GitHub Actions: pruebas → build y push → actualizar `k8s/apps/web`, con el resumen "Imagen publicada" (`5e46bde`) |
| [Docker Hub](../../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.44.23%20AM.jpeg) | Repositorios `andernoleo/kubelab-web` y `andernoleo/kubelab-api` |
| [Commits del bot](../../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.44.55%20AM.jpeg) | `ci(web)` y `ci(api): desplegar imagen 5e46bde` hechos por `github-actions[bot]` |
| [Arranque de Argo CD](../../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.57.46%20AM.jpeg) | `scripts/nodos/arranque-argocd.sh` instalando Argo CD |
| [Applications sincronizando](../../imagenes/WhatsApp%20Image%202026-11-05%20at%208.06.33%20PM.jpeg) | `kubectl get applications -n argocd` durante la primera sincronización |
| [Applications Synced](../../imagenes/WhatsApp%20Image%202026-11-05%20at%208.08.16%20PM.jpeg) | La plataforma ya `Synced` |
| [Argo CD: 18 Synced y Healthy](../../imagenes/WhatsApp%20Image%202026-11-05%20at%209.29.50%20PM.jpeg) | Interfaz de Argo CD (vista de tarjetas) |
| [Argo CD: lista](../../imagenes/WhatsApp%20Image%202026-11-05%20at%209.30.01%20PM.jpeg) | Interfaz de Argo CD (vista de lista) con origen, destino y estado de cada Application |

### Secretos

| Captura | Qué muestra |
|---|---|
| [Doppler](../../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.05.57%20AM.jpeg) | Proyecto `kubelab` con los entornos y la config `prd` |

### Aplicación

| Captura | Qué muestra |
|---|---|
| [Pods y esquema de la base](../../imagenes/WhatsApp%20Image%202026-11-05%20at%209.32.12%20PM.jpeg) | Pods de `kubelab` en `Running` y logs del Job `db-init` ("Esquema aplicado") |
| [Web de inventario](../../imagenes/WhatsApp%20Image%202026-11-05%20at%209.33.57%20PM.jpeg) | http://app.grupo7.lab con productos y la versión `5e46bde` de web y API |
| [API /health](../../imagenes/WhatsApp%20Image%202026-11-05%20at%209.33.57%20PM%20%281%29.jpeg) | `{"status":"ok","version":"5e46bde"}` |
| [API /metrics](../../imagenes/WhatsApp%20Image%202026-11-05%20at%209.33.57%20PM%20%282%29.jpeg) | Métricas en formato Prometheus |
