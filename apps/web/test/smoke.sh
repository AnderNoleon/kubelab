#!/usr/bin/env bash
# Prueba de humo de la web: construye la imagen, la levanta y verifica que responde.
set -euo pipefail
cd "$(dirname "$0")/.."

docker build -t kubelab-web:test --build-arg VERSION=test .
docker run -d --name kubelab-web-test -p 18080:8080 kubelab-web:test >/dev/null
trap 'docker rm -f kubelab-web-test >/dev/null' EXIT

for i in $(seq 1 15); do curl -fs http://localhost:18080/healthz >/dev/null && break; sleep 1; done

curl -fs http://localhost:18080/healthz | grep -q ok
curl -fs http://localhost:18080/ | grep -q "KubeLab · Inventario"
curl -fs http://localhost:18080/ | grep -q "web <code>test</code>"
echo "OK: la web responde y muestra la versión"
