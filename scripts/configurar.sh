#!/usr/bin/env bash
# Reemplaza los marcadores del repositorio con los datos del grupo. Ejecutar UNA vez en la raíz del repo:
#   bash scripts/configurar.sh <usuario-dockerhub> <url-del-repo-github>
# Ejemplo:
#   bash scripts/configurar.sh grupo7kubelab https://github.com/grupo7/kubelab.git
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -ne 2 ]]; then
  echo "Uso: bash scripts/configurar.sh <usuario-dockerhub> <url-repo-github>"; exit 1
fi
DH_USER="$1"
REPO_URL="$2"

sed -i "s#DOCKERHUB_USER/#${DH_USER}/#g" k8s/apps/api/deployment.yaml k8s/apps/web/deployment.yaml
sed -i "s#REPO_URL#${REPO_URL}#g" k8s/argocd/root.yaml k8s/argocd/apps/*.yaml scripts/generar-apps-argocd.py

echo "Imágenes:"; grep -h "image:" k8s/apps/api/deployment.yaml k8s/apps/web/deployment.yaml
echo "Repo:";     grep -h "repoURL: http" k8s/argocd/root.yaml
if grep -rq "REPO_URL\|DOCKERHUB_USER" k8s; then echo "ATENCIÓN: quedan marcadores sin reemplazar"; exit 1; fi
echo "Listo. Revisen con 'git diff' y hagan commit."
