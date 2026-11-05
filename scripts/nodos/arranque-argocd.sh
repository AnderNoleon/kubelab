#!/usr/bin/env bash
# Arranque de GitOps. Se ejecuta UNA sola vez en k8s-cp, dentro del repo clonado:
#   bash scripts/nodos/arranque-argocd.sh
# Hace las tres únicas acciones manuales del proyecto:
#   1) instala Argo CD (después se administra a sí mismo desde k8s/argocd/install)
#   2) crea el Secret con el token de servicio de Doppler (SEC-04: único secreto creado a mano)
#   3) aplica la Application raíz; desde ahí todo lo despliega Argo CD
set -euo pipefail
cd "$(dirname "$0")/../.."

if grep -rq "REPO_URL" k8s/argocd; then
  echo "Primero ejecuten scripts/configurar.sh y hagan push"; exit 1
fi

echo ">> 1/3 Instalando Argo CD"
kubectl apply -k k8s/argocd/install --server-side --force-conflicts
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s

echo ">> 2/3 Token de servicio de Doppler (proyecto kubelab, config prd)"
if kubectl -n doppler-operator-system get secret doppler-token-secret >/dev/null 2>&1; then
  echo "   Ya existe, se conserva"
else
  read -r -s -p "   Pegue el token (dp.st.prd...) y presione Enter: " TOKEN; echo
  kubectl create namespace doppler-operator-system --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n doppler-operator-system create secret generic doppler-token-secret \
    --from-literal=serviceToken="$TOKEN"
  unset TOKEN
fi

echo ">> 3/3 Application raíz"
kubectl apply -f k8s/argocd/root.yaml

echo
echo "Contraseña inicial del usuario admin de Argo CD:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
echo "Sigan el avance con:  kubectl get applications -n argocd -w"
