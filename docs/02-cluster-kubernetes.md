# 2. Clúster Kubernetes (INF-04, INF-05)

## Por qué k3s

La computadora asignada tiene **4 núcleos (i5-3470S) y 5.66 GB de RAM**, y Proxmox usa cerca de 1.5 GB. Con lo que queda (unos 4 GB) hay que levantar el clúster más Argo CD, Prometheus, Loki, Grafana, PostgreSQL y las aplicaciones. Por eso, de acuerdo con el docente, se usa una distribución liviana y un solo nodo (ver [Clúster de un solo nodo](#clúster-de-un-solo-nodo)).

| Opción | A favor | En contra | Decisión |
|---|---|---|---|
| **k3s** | Distribución certificada de Kubernetes en un solo binario; el control plane usa unos 500 MB contra más de 1 GB de kubeadm; instalación en un comando | Trae Traefik, ServiceLB, almacenamiento local y metrics-server propios | **Elegida**: esos cuatro se desactivan y el proyecto instala los suyos con Argo CD |
| kubeadm | Herramienta oficial, componentes estándar | Control plane más pesado (etcd, apiserver, controller y scheduler por separado); no cabe con holgura en 4 GB | Descartada por memoria |
| RKE2 | Seguro por defecto | Más pesado que kubeadm | Descartada |

k3s se instala con:

```
--disable traefik --disable servicelb --disable local-storage --disable metrics-server
```

Así, todo lo que corre en el clúster lo define el repositorio (GitOps).

Versión: canal **stable** de k3s, con containerd y Flannel (VXLAN) incluidos.

## Clúster de un solo nodo

| Nombre | IP | vCPU | RAM | Disco | Rol |
|---|---|---|---|---|---|
| k8s-cp | 10.10.10.10 | 2 | 4 GB | 25 GB | control plane que también ejecuta todas las cargas |

El diseño original era 1 control plane + workers. Se intentó dos veces:

1. **1 control plane + 2 workers** (1.25 GB + 1.5 GB + 1.5 GB): los tres nodos quedaron `Ready`, pero al desplegar la plataforma la memoria del host se saturó.
2. **1 control plane + 1 worker** (se eliminó `k8s-w2`): el host siguió al límite, con la RAM al 95 %.

![Primer intento: tres nodos Ready](../imagenes/WhatsApp%20Image%202026-11-04%20at%2011.57.43%20PM.jpeg)
*Primer intento: `instalar-kubernetes.sh` termina con k8s-cp, k8s-w1 y k8s-w2 en `Ready`.*

![Segundo intento: se elimina k8s-w2](../imagenes/WhatsApp%20Image%202026-11-05%20at%208.06.26%20PM.jpeg)
*Segundo intento: `kubectl delete node k8s-w2`; quedan k8s-cp y k8s-w1.*

![RAM del host al 95 %](../imagenes/WhatsApp%20Image%202026-11-05%20at%208.23.20%20PM.jpeg)
*Resumen de Proxmox durante el segundo intento: 5.40 de 5.66 GiB de RAM en uso. Por esto el clúster quedó en un solo nodo.*

Cada VM extra repite el sistema operativo, el kubelet y los DaemonSets, y con 5.66 GB en el host esa sobrecarga no cabe. Por eso, **de acuerdo con el docente**, el clúster quedó en un solo nodo con 4 GB: `k8s-cp`. Ya no existen `k8s-w1` ni `k8s-w2`.

Para que el control plane ejecute las aplicaciones se le quitó el taint `node-role.kubernetes.io/control-plane:NoSchedule`, tanto del servicio de k3s (para que no vuelva al reiniciar) como del nodo:

```bash
# en k8s-cp
sudo sed -i "/--node-taint/d; /control-plane:NoSchedule/d" /etc/systemd/system/k3s.service
sudo systemctl daemon-reload && sudo systemctl restart k3s
kubectl taint nodes k8s-cp node-role.kubernetes.io/control-plane:NoSchedule-
```

## Instalación

Desde la Shell de Proxmox:

```bash
WORKERS=0 bash scripts/proxmox/instalar-kubernetes.sh   # un solo nodo (configuración actual)
WORKERS=2 bash scripts/proxmox/instalar-kubernetes.sh   # con workers, si el host tiene más RAM
```

Con `WORKERS=0` el script no agrega el taint al control plane ni espera workers. Equivale a:

```bash
# en k8s-cp
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - server --node-ip 10.10.10.10 \
  --disable traefik --disable servicelb --disable local-storage --disable metrics-server \
  --write-kubeconfig-mode 644
```

Con `WORKERS>=1` el script, además, agrega `--node-taint node-role.kubernetes.io/control-plane:NoSchedule` al servidor, une cada worker (`k8s-w1`, `k8s-w2`, ...) con el token de `/var/lib/rancher/k3s/server/node-token` y les pone el rol `worker`.

## Verificación

```bash
ssh kube@10.10.10.10
kubectl get nodes -o wide
kubectl describe node k8s-cp | grep Taints
```

Resultado esperado: 1 nodo en `Ready`, `k8s-cp` con rol `control-plane`, y `Taints: <none>`.

## Dónde corren las aplicaciones (INF-05)

Con un solo nodo, el control plane ejecuta las aplicaciones: api, web, postgres y las herramientas de plataforma y observabilidad se programan en `k8s-cp`. Comprobar:

```bash
kubectl get pods -A -o wide        # columna NODE: k8s-cp en todos
```

Separar el control plane de las cargas es la práctica recomendada, y el repositorio lo deja preparado: con un host con más RAM se crean workers (`WORKERS=2` en `crear-vms.sh`, `preparar-nodos.sh` e `instalar-kubernetes.sh`) y se vuelve a poner el taint:

```bash
kubectl taint nodes k8s-cp node-role.kubernetes.io/control-plane:NoSchedule
```

![Taint NoSchedule en k8s-cp con workers](../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.00.33%20AM.jpeg)
*Así quedaba el control plane cuando el clúster tenía workers: taint `NoSchedule` en k8s-cp.*

Desde ese momento, api, web, postgres y las herramientas solo se programan en los workers, y en `k8s-cp` quedan únicamente los DaemonSets de observabilidad (Promtail y node-exporter, que tienen toleration).
