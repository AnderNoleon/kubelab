# 5. Secretos con Doppler (SEC-01 a SEC-04)

**Ninguna credencial está en este repositorio ni en su historial.** Todas viven en Doppler, proyecto `kubelab`, configuración `prd`.

![Proyecto kubelab en Doppler](../imagenes/WhatsApp%20Image%202026-11-05%20at%2012.05.57%20AM.jpeg)
*Proyecto `kubelab` en Doppler; el clúster y GitHub Actions leen la config `prd`.*

## Secretos en Doppler (SEC-01)

| Nombre | Ejemplo / regla | Lo usa |
|---|---|---|
| `POSTGRES_USER` | `kubelab` | PostgreSQL |
| `POSTGRES_PASSWORD` | 24 caracteres **solo letras y números** | PostgreSQL |
| `POSTGRES_DB` | `kubelab` | PostgreSQL |
| `DATABASE_URL` | `postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres.kubelab.svc.cluster.local:5432/${POSTGRES_DB}` | API, Job db-init |
| `DB_READONLY_USER` | `docente_ro` | Job db-init (crea el usuario de solo lectura) |
| `DB_READONLY_PASSWORD` | solo letras y números | Job db-init |
| `GRAFANA_ADMIN_USER` | `admin` | Grafana |
| `GRAFANA_ADMIN_PASSWORD` | solo letras y números | Grafana |
| `GRAFANA_VIEWER_USER` | `docente` | Job grafana-usuario-docente |
| `GRAFANA_VIEWER_PASSWORD` | solo letras y números | Job grafana-usuario-docente |
| `DOCKERHUB_USERNAME` | usuario de Docker Hub | GitHub Actions |
| `DOCKERHUB_TOKEN` | Access Token de Docker Hub (Read & Write) | GitHub Actions |

`DATABASE_URL` usa referencias `${...}` de Doppler: si cambia la clave, la URL se actualiza sola. Las claves llevan solo letras y números para no tener que codificarlas dentro de la URL.

## Hacia Kubernetes (SEC-02)

1. El chart `doppler-kubernetes-operator` 1.7.5 se instala con Argo CD (`platform-doppler-operator`).
2. `k8s/platform/doppler/secrets/dopplersecrets.yaml` define dos `DopplerSecret` versionados:
   - `kubelab` → Secret `kubelab-secrets` en el namespace `kubelab`, solo con las 6 claves de la base de datos.
   - `monitoring` → Secret `grafana-secrets` en `monitoring`, solo con las 4 claves de Grafana.
3. El operator revisa Doppler cada 60 s. La API y PostgreSQL tienen la anotación `secrets.doppler.com/reload: "true"` y se reinician solas si cambia un secreto.

## Hacia GitHub Actions (SEC-03)

Los workflows instalan la CLI de Doppler (`dopplerhq/cli-action@v4`) y leen `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` con `doppler secrets get`. El token se oculta en los logs con `::add-mask::`.

## Los únicos tokens creados a mano (SEC-04)

Son dos tokens de servicio de Doppler, de solo lectura, que nunca pasan por el repositorio:

| Token | Dónde se guarda | Cómo se crea |
|---|---|---|
| `doppler-token-secret` | Secret en `doppler-operator-system` | `scripts/nodos/arranque-argocd.sh` lo pide por teclado |
| `DOPPLER_TOKEN` | GitHub → Settings → Secrets and variables → Actions | a mano en la interfaz de GitHub |

Procedimiento:

1. Doppler → proyecto `kubelab` → config `prd` → **Access → Service Tokens → Generate**, acceso **Read**. Crear uno llamado `k8s-operator` y otro `github-actions`.
2. `k8s-operator`: ejecutar `bash scripts/nodos/arranque-argocd.sh` en k8s-cp y pegarlo cuando lo pida. Equivale a:

   ```bash
   kubectl create namespace doppler-operator-system
   kubectl -n doppler-operator-system create secret generic doppler-token-secret --from-literal=serviceToken=dp.st.prd.XXXX
   ```

3. `github-actions`: guardarlo en GitHub como secreto de repositorio `DOPPLER_TOKEN`.

Verificar: `kubectl get dopplersecrets -n doppler-operator-system` y `kubectl get secret kubelab-secrets -n kubelab`.

## Para no filtrar nada

- Revisar `git diff --cached` antes de cada commit.
- Nunca pegar tokens en issues, pull requests ni en el README.
- Las credenciales de solo lectura del docente se envían por un canal privado (ACC-03), nunca por el repositorio.
