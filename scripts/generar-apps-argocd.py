#!/usr/bin/env python3
"""Genera k8s/argocd/apps/*.yaml (una Application de Argo CD por componente).
Se deja en el repo para documentar cómo se construyeron; si cambian algo, edítenlo aquí y vuelvan a correrlo."""
import os, yaml

REPO = "https://github.com/AnderNoleon/kubelab.git"
OUT = os.path.join(os.path.dirname(__file__), "..", "k8s", "argocd", "apps")
RETRY = {"limit": 10, "backoff": {"duration": "20s", "factor": 2, "maxDuration": "5m"}}

def app(name, wave, namespace, *, sources=None, source=None, component, extra_sync=(), prune=True, cascade=True, **spec_extra):
    sync = {"automated": {"prune": prune, "selfHeal": True},
            "syncOptions": ["CreateNamespace=true", *extra_sync], "retry": RETRY}
    spec = {"project": "default"}
    if source: spec["source"] = source
    if sources: spec["sources"] = sources
    spec["destination"] = {"server": "https://kubernetes.default.svc", "namespace": namespace}
    spec.update(spec_extra)
    spec["syncPolicy"] = sync
    return {"apiVersion": "argoproj.io/v1alpha1", "kind": "Application",
            "metadata": {"name": name, "namespace": "argocd",
                         "labels": {"kubelab/componente": component},
                         "annotations": {"argocd.argoproj.io/sync-wave": str(wave)},
                         # cascade=False: borrar la Application NO borra lo que instaló (Argo CD, namespaces)
                         **({"finalizers": ["resources-finalizer.argocd.argoproj.io"]} if cascade else {})},
            "spec": spec}

def git(path):
    return {"repoURL": REPO, "targetRevision": "main", "path": path}

def helm(repo, chart, version, values_path, release, extra_path=None):
    s = [{"repoURL": repo, "chart": chart, "targetRevision": version,
          "helm": {"releaseName": release, "valueFiles": [f"$values/{values_path}"]}},
         {"repoURL": REPO, "targetRevision": "main", "ref": "values"}]
    if extra_path:
        s.append(git(extra_path))
    return s

apps = [
    # ---------- Plataforma ----------
    app("platform-namespaces", -2, "default", source=git("k8s/platform/namespaces"), component="plataforma", cascade=False),
    app("platform-argocd", -1, "argocd", source=git("k8s/argocd/install"), component="plataforma",
        extra_sync=["ServerSideApply=true"], cascade=False),
    app("platform-metallb", 0, "metallb-system", component="plataforma",
        source={"repoURL": "https://metallb.github.io/metallb", "chart": "metallb", "targetRevision": "0.15.3",
                "helm": {"releaseName": "metallb"}},
        ignoreDifferences=[{"group": "apiextensions.k8s.io", "kind": "CustomResourceDefinition",
                            "jsonPointers": ["/spec/conversion/webhook/clientConfig/caBundle"]}],
        extra_sync=["RespectIgnoreDifferences=true"]),
    app("platform-nfs-storage", 0, "nfs-provisioner", component="plataforma",
        sources=helm("https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/",
                     "nfs-subdir-external-provisioner", "4.0.18", "k8s/platform/nfs/values.yaml", "nfs-provisioner")),
    app("platform-metrics-server", 0, "kube-system", component="plataforma",
        sources=helm("https://kubernetes-sigs.github.io/metrics-server/", "metrics-server", "3.14.0",
                     "k8s/platform/metrics-server/values.yaml", "metrics-server")),
    app("platform-doppler-operator", 0, "doppler-operator-system", component="plataforma",
        source={"repoURL": "https://helm.doppler.com", "chart": "doppler-kubernetes-operator",
                "targetRevision": "1.7.5", "helm": {"releaseName": "doppler-operator"}},
        extra_sync=["ServerSideApply=true"]),
    app("platform-metallb-config", 1, "metallb-system", source=git("k8s/platform/metallb/config"), component="plataforma"),
    app("platform-doppler-secrets", 1, "doppler-operator-system", source=git("k8s/platform/doppler/secrets"),
        component="plataforma"),
    app("platform-traefik", 2, "traefik", component="plataforma",
        sources=helm("https://traefik.github.io/charts", "traefik", "42.2.0",
                     "k8s/platform/traefik/values.yaml", "traefik"),
        extra_sync=["ServerSideApply=true"]),
    app("platform-argocd-ingress", 3, "argocd", source=git("k8s/argocd/ingress"), component="plataforma"),
    # ---------- Observabilidad ----------
    app("observability-prometheus", 3, "monitoring", component="observabilidad",
        sources=helm("https://prometheus-community.github.io/helm-charts", "prometheus", "29.40.3",
                     "k8s/observability/prometheus/values.yaml", "prometheus",
                     extra_path="k8s/observability/prometheus/manifests"),
        extra_sync=["ServerSideApply=true"]),
    app("observability-loki", 3, "monitoring", source=git("k8s/observability/loki"), component="observabilidad"),
    app("observability-promtail", 4, "monitoring", source=git("k8s/observability/promtail"), component="observabilidad"),
    app("observability-grafana", 4, "monitoring", component="observabilidad",
        sources=helm("https://grafana-community.github.io/helm-charts", "grafana", "14.3.0",
                     "k8s/observability/grafana/values.yaml", "grafana",
                     extra_path="k8s/observability/grafana/manifests")),
    # ---------- Aplicaciones ----------
    app("database", 4, "kubelab", source=git("k8s/apps/database"), component="aplicaciones"),
    app("api", 5, "kubelab", source=git("k8s/apps/api"), component="aplicaciones"),
    app("web", 5, "kubelab", source=git("k8s/apps/web"), component="aplicaciones"),
]

os.makedirs(OUT, exist_ok=True)
for a in apps:
    with open(os.path.join(OUT, a["metadata"]["name"] + ".yaml"), "w") as f:
        f.write("# Generado por scripts/generar-apps-argocd.py\n")
        yaml.safe_dump(a, f, sort_keys=False, allow_unicode=True, width=120)
print(f"{len(apps)} Applications en {os.path.normpath(OUT)}")
