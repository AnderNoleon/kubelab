# 6. Persistencia, observabilidad y alta disponibilidad

## Persistencia (PER-01 a PER-03)

- **Aprovisionador:** `nfs-subdir-external-provisioner` 4.0.18 con un servidor NFS en el host Proxmox (`/srv/nfs/kubelab`).
- **StorageClass por defecto:** `nfs-client`. Comprobar con `kubectl get storageclass`, que debe mostrar `(default)`.
- **PVCs:**

| Componente | Tipo | PVC | Tamaño |
|---|---|---|---|
| PostgreSQL | StatefulSet | `datos-postgres-0` | 5 Gi |
| Loki | StatefulSet | `datos-loki-0` | 5 Gi |
| Prometheus | Deployment (chart) | `prometheus-server` | 4 Gi |
| Grafana | Deployment (chart) | `grafana` | 2 Gi |

Prueba de persistencia:

```bash
curl -X POST http://api.grupo7.lab/productos -H 'Content-Type: application/json' -d '{"nombre":"Prueba","cantidad":1,"precio":1}'
kubectl delete pod postgres-0 -n kubelab
kubectl wait --for=condition=Ready pod/postgres-0 -n kubelab --timeout=120s
curl http://api.grupo7.lab/productos     # "Prueba" sigue ahí
```

PostgreSQL tiene una `startupProbe` (`k8s/apps/database/statefulset.yaml`, hasta 60 intentos cada 10 s): la primera inicialización de la base sobre NFS tarda varios minutos y, sin ella, la liveness probe reiniciaba el pod antes de que terminara. La liveness solo empieza a actuar cuando la startupProbe pasa.

![Pods de kubelab y logs del Job db-init](../imagenes/WhatsApp%20Image%202026-11-05%20at%209.32.12%20PM.jpeg)
*`postgres-0`, api y web en `Running`; el Job `db-init` crea la tabla, los datos de ejemplo y el usuario de solo lectura ("Esquema aplicado").*

## Observabilidad (OBS-01 a OBS-04)

- **Prometheus** (chart 29.40.3) recolecta:
  - del nodo: node-exporter, DaemonSet (1 pod, en `k8s-cp`);
  - de Kubernetes: kube-state-metrics, kubelet y cAdvisor;
  - de la API: los pods con la anotación `prometheus.io/scrape: "true"` en el puerto 3000, ruta `/metrics`.

  Se verifica en http://prometheus.grupo7.lab/targets.
- **Loki** (monolítico, PVC) y **Promtail** (DaemonSet, también en el control plane, con toleration). Se verifica con `kubectl get pods -n monitoring -l app=promtail -o wide`: debe haber 1 pod, en `k8s-cp` (uno por nodo).
- **Grafana** (chart 14.3.0): las fuentes Prometheus y Loki se definen en `values.yaml`, y el dashboard `KubeLab · Grupo 7` se carga desde `k8s/observability/grafana/manifests/dashboards/kubelab.json` con el sidecar. No hay nada configurado a mano. El límite de memoria del contenedor es de **448Mi** (`k8s/observability/grafana/values.yaml`): con un valor menor se reiniciaba por `OOMKilled`.

![Endpoint /metrics de la API](../imagenes/WhatsApp%20Image%202026-11-05%20at%209.33.57%20PM%20%282%29.jpeg)
*http://api.grupo7.lab/metrics: métricas en formato Prometheus que recolecta Prometheus.*

Paneles del dashboard: peticiones por segundo, réplicas disponibles de api y web, nodos Ready, solicitudes por segundo por ruta y código, latencia p95, CPU y memoria por pod, réplicas activas frente al objetivo del HPA, CPU de los nodos y logs de Loki.

## Alta disponibilidad y escalado (HA-01 a HA-05)

| Requisito | Dónde |
|---|---|
| Mínimo 2 réplicas | `hpa.yaml` con `minReplicas: 2` (el Deployment no fija `replicas`, para que Argo CD no compita con el HPA) |
| requests, limits y probes | `deployment.yaml` de api y web; la API usa `/health` (liveness) y `/ready` (readiness, comprueba la base) |
| PodDisruptionBudget | `pdb.yaml` con `minAvailable: 1` |
| metrics-server + HPA de 2 a 6 por CPU | `k8s/platform/metrics-server`, `hpa.yaml` (objetivo 50 % de CPU) |
| Prueba de carga | `loadtest/k6-carga.js` |

![Endpoint /health de la API](../imagenes/WhatsApp%20Image%202026-11-05%20at%209.33.57%20PM%20%281%29.jpeg)
*http://api.grupo7.lab/health, la ruta que usa la liveness probe de la API.*

Con un solo nodo, las 2 réplicas y el PDB protegen frente a la caída o el reemplazo de **un pod** (un reinicio, un despliegue, un `kubectl delete pod`), no frente a la caída del nodo: si `k8s-cp` se apaga, se detiene todo el clúster. Para tolerar la caída de un nodo hacen falta workers (ver [docs/02](02-cluster-kubernetes.md#dónde-corren-las-aplicaciones-inf-05)).

### Demostración del escalado (HA-05)

Con la VPN conectada y los hosts configurados, instalar k6 (https://grafana.com/docs/k6/latest/set-up/install-k6/) y:

```bash
# terminal 1 (en k8s-cp)
kubectl get hpa -n kubelab -w
# terminal 2
k6 run loadtest/k6-carga.js
```

Resultado esperado: el HPA de `api` sube de 2 a 4–6 réplicas durante la carga y vuelve a 2 aproximadamente un minuto después. Grabar la pantalla y guardarla en `docs/evidencias/`.

### Eliminación de un pod sin corte

```bash
# terminal 1: pedidos continuos
while true; do curl -s -o /dev/null -w "%{http_code} " http://api.grupo7.lab/productos; sleep 0.3; done
# terminal 2
kubectl delete -n kubelab $(kubectl get pod -n kubelab -l app=api -o name | head -1)   # borra UNO solo
```

La terminal 1 debe seguir mostrando `200`: la otra réplica atiende mientras Kubernetes crea la nueva.
