# Evidencias

Guardar aquí las capturas y grabaciones con estos nombres:

| Archivo | Qué muestra |
|---|---|
| `01-nodos-ready.png` | `kubectl get nodes -o wide` con los 3 nodos Ready |
| `02-proxmox-vms.png` | Proxmox con las 3 VMs encendidas |
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
