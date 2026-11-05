# 2. Clúster Kubernetes (INF-04, INF-05)

## Por qué kubeadm

| Opción | A favor | En contra | Decisión |
|---|---|---|---|
| **kubeadm** | Es la herramienta oficial del proyecto Kubernetes; instala componentes estándar sin modificaciones; obliga a entender cada pieza (containerd, CNI, certificados, join) | Más pasos manuales que k3s | **Elegida** |
| k3s | Muy liviano, un solo binario | Trae Traefik, ServiceLB y almacenamiento local propios que habría que desactivar para usar MetalLB y nuestro Traefik | Descartada |
| RKE2 | Seguro por defecto | Más pesado y con más opciones propias de Rancher | Descartada |

Con kubeadm, todo lo que corre en el clúster lo instalamos nosotros desde el repo, lo que encaja con GitOps.

Versión: **Kubernetes v1.36**, runtime **containerd**, red de pods **Flannel** (VXLAN, `10.244.0.0/16`).

## Instalación

Desde la Shell de Proxmox:

```bash
bash scripts/proxmox/instalar-kubernetes.sh
```

Equivale a:

```bash
# en k8s-cp
sudo kubeadm init --apiserver-advertise-address=10.10.10.10 --pod-network-cidr=10.244.0.0/16
mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubeadm token create --print-join-command   # copiar la salida

# en k8s-w1, k8s-w2, k8s-w3
sudo kubeadm join 10.10.10.10:6443 --token ... --discovery-token-ca-cert-hash sha256:...

# en k8s-cp
kubectl label node k8s-w1 k8s-w2 k8s-w3 node-role.kubernetes.io/worker=
```

## Verificación

```bash
ssh kube@10.10.10.10
kubectl get nodes -o wide
```

Resultado esperado: 4 nodos en `Ready`; `k8s-cp` con rol `control-plane` y los otros tres con rol `worker`.

## El control plane no ejecuta aplicaciones (INF-05)

kubeadm deja en `k8s-cp` el taint `node-role.kubernetes.io/control-plane:NoSchedule`, así que api, web y postgres solo se programan en los workers. Comprobar:

```bash
kubectl describe node k8s-cp | grep Taints
kubectl get pods -n kubelab -o wide        # columna NODE: solo k8s-w1, k8s-w2, k8s-w3
```

Los únicos pods en `k8s-cp` son los del sistema y los DaemonSets de observabilidad (Promtail y node-exporter), que deben correr en todos los nodos para recoger sus logs y métricas.
