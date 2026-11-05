# 2. Clúster Kubernetes (INF-04, INF-05)

## Por qué k3s

La computadora asignada tiene **4 núcleos (i5-3470S) y 5.66 GB de RAM**, y Proxmox usa cerca de 1.5 GB. Con lo que queda (unos 4 GB) hay que levantar 3 nodos más Argo CD, Prometheus, Loki, Grafana, PostgreSQL y las aplicaciones. Por eso, de acuerdo con el docente, se usa una distribución liviana y 2 workers.

| Opción | A favor | En contra | Decisión |
|---|---|---|---|
| **k3s** | Distribución certificada de Kubernetes en un solo binario; el control plane usa unos 500 MB contra más de 1 GB de kubeadm; instalación en un comando | Trae Traefik, ServiceLB, almacenamiento local y metrics-server propios | **Elegida**: esos cuatro se desactivan y el proyecto instala los suyos con Argo CD |
| kubeadm | Herramienta oficial, componentes estándar | Control plane más pesado (etcd, apiserver, controller y scheduler por separado); no cabe con holgura en 4 GB | Descartada por memoria |
| RKE2 | Seguro por defecto | Más pesado que kubeadm | Descartada |

k3s se instala con:

```
--disable traefik --disable servicelb --disable local-storage --disable metrics-server
--node-taint node-role.kubernetes.io/control-plane:NoSchedule
```

Así, todo lo que corre en el clúster lo define el repositorio (GitOps), igual que con kubeadm.

Versión: canal **stable** de k3s, con containerd y Flannel (VXLAN) incluidos.

## Instalación

Desde la Shell de Proxmox:

```bash
bash scripts/proxmox/instalar-kubernetes.sh            # 2 workers
WORKERS=1 bash scripts/proxmox/instalar-kubernetes.sh  # si solo hay 1 worker
```

Equivale a:

```bash
# en k8s-cp
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - server --node-ip 10.10.10.10 \
  --disable traefik --disable servicelb --disable local-storage --disable metrics-server \
  --node-taint node-role.kubernetes.io/control-plane:NoSchedule --write-kubeconfig-mode 644
sudo cat /var/lib/rancher/k3s/server/node-token      # copiar el token

# en k8s-w1 y k8s-w2
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable K3S_URL=https://10.10.10.10:6443 K3S_TOKEN=<token> sh -s - agent --node-ip 10.10.10.1X

# en k8s-cp
kubectl label node k8s-w1 node-role.kubernetes.io/worker=worker
kubectl label node k8s-w2 node-role.kubernetes.io/worker=worker
```

## Verificación

```bash
ssh kube@10.10.10.10
kubectl get nodes -o wide
```

Resultado esperado: 3 nodos en `Ready`, `k8s-cp` con rol `control-plane` y los otros dos con rol `worker`.

## El control plane no ejecuta aplicaciones (INF-05)

`k8s-cp` tiene el taint `node-role.kubernetes.io/control-plane:NoSchedule`, así que api, web, postgres y las herramientas solo se programan en los workers. Comprobar:

```bash
kubectl describe node k8s-cp | grep Taints
kubectl get pods -n kubelab -o wide        # columna NODE: solo k8s-w1 y k8s-w2
```

Los únicos pods de `k8s-cp` son los DaemonSets de observabilidad (Promtail y node-exporter), que deben correr en todos los nodos para recoger sus logs y métricas.
