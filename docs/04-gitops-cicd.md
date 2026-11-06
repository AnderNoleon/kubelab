# 4. CI/CD y GitOps (APP-04, APP-05, APP-06, CD-01 a CD-04)

## Pipelines (GitHub Actions)

| Archivo | Se activa con | Qué hace |
|---|---|---|
| `.github/workflows/api.yml` | cambios en `apps/api/**` | llama al flujo común con `app: api` y `npm test` |
| `.github/workflows/web.yml` | cambios en `apps/web/**` | llama al flujo común con `app: web` y la prueba de humo |
| `.github/workflows/_build-deploy.yml` | reutilizable | pruebas → build → push `usuario/kubelab-<app>:<hash>` → commit del tag en `k8s/apps/<app>/deployment.yaml` |

- En **pull requests** solo se ejecutan las pruebas.
- En **push a main** se prueba, se publica y se actualiza el manifiesto.
- La etiqueta es siempre `${GITHUB_SHA::7}`. **No se publica `latest`** (APP-05).
- Las credenciales de Docker Hub salen de Doppler (ver `05-secretos-doppler.md`).
- El commit del bot lleva `[skip ci]` y no toca `apps/`, así que no dispara otro pipeline.

![Run de GitHub Actions del workflow web](../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.43.31%20AM.jpeg)
*Run del workflow `web`: pruebas → build y push → actualizar `k8s/apps/web`, con el resumen "Imagen publicada" (`andernoleo/kubelab-web:5e46bde`).*

![Repositorios en Docker Hub](../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.44.23%20AM.jpeg)
*Docker Hub: repositorios `andernoleo/kubelab-web` y `andernoleo/kubelab-api`.*

![Commits del bot de GitHub Actions](../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.44.55%20AM.jpeg)
*Commits `ci(web)` y `ci(api): desplegar imagen 5e46bde [skip ci]` hechos por `github-actions[bot]`.*

## Argo CD

### Arranque (única vez, en k8s-cp)

```bash
git clone https://github.com/<usuario>/<repo>.git && cd <repo>
bash scripts/nodos/arranque-argocd.sh
```

El script:

1. Instala Argo CD v3.5.6 desde `k8s/argocd/install` (kustomize: manifiesto oficial + cuenta `docente` + modo HTTP detrás de Traefik).
2. Pide el token de servicio de Doppler y crea el Secret `doppler-token-secret` (único secreto manual).
3. Aplica `k8s/argocd/root.yaml`.

![Ejecución de arranque-argocd.sh](../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.57.46%20AM.jpeg)
*`scripts/nodos/arranque-argocd.sh` en k8s-cp instalando Argo CD.*

Desde ese momento **nadie ejecuta `kubectl apply`**: todo lo despliega Argo CD desde Git.

### App of apps (CD-03)

`root` lee `k8s/argocd/apps/` y crea 17 Applications, ordenadas por `sync-wave`:

| Wave | Applications |
|---|---|
| -2, -1 | platform-namespaces, platform-argocd (Argo CD se administra a sí mismo) |
| 0 | platform-metallb, platform-nfs-storage, platform-metrics-server, platform-doppler-operator |
| 1 | platform-metallb-config, platform-doppler-secrets |
| 2 | platform-traefik |
| 3 | platform-argocd-ingress, observability-prometheus, observability-loki |
| 4 | observability-promtail, observability-grafana, database |
| 5 | api, web |

![Argo CD con 18 Applications Synced y Healthy](../imagenes/WhatsApp%20Image%202026-11-05%20at%209.29.50%20PM.jpeg)
*Argo CD: 18 Applications `Synced` y 18 `Healthy` (filtros de la izquierda).*

![Lista de Applications en Argo CD](../imagenes/WhatsApp%20Image%202026-11-05%20at%209.30.01%20PM.jpeg)
*Vista de lista: origen (repo o chart con su versión), destino y estado de cada Application.*

Todas tienen `automated: {prune: true, selfHeal: true}` (CD-04). Prueba de selfHeal:

```bash
kubectl scale deploy/web -n kubelab --replicas=0   # cambio manual
# en segundos Argo CD lo revierte; el HPA vuelve a dejar 2 réplicas
kubectl delete ingressroute api -n kubelab          # Argo CD la vuelve a crear
```

Las Applications se generan con `scripts/generar-apps-argocd.py`. Si cambian una versión de chart, edítenla ahí y vuelvan a correrlo.

### Usuario de solo lectura para el docente (ACC-03)

La cuenta `docente` (rol `role:readonly`) está declarada en `k8s/argocd/install`. Su clave **no** va en el repo; se define una vez con la CLI:

```bash
# en k8s-cp
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v3.5.6/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd && rm argocd
argocd login argocd.grupo7.lab --username admin --grpc-web --plaintext   # clave de admin
argocd account update-password --account docente --current-password '<clave admin>' --new-password '<clave docente>'
```

Para que `argocd.grupo7.lab` resuelva en k8s-cp: `echo "10.10.10.200 argocd.grupo7.lab" | sudo tee -a /etc/hosts`.

## Flujo de trabajo del grupo

- Ramas `feat/...`, `fix/...`, `docs/...` y fusión por pull request a `main`.
- Commits con Conventional Commits: `feat(api): ...`, `fix(web): ...`, `docs: ...`, `ci: ...`, `chore: ...`.
- Regla de protección de `main` (Settings → Rules → Rulesets): **Block force pushes** y **Restrict deletions**. No activar "Require a pull request", porque bloquearía el commit automático del pipeline.
