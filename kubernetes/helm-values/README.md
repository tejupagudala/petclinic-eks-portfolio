# Helm values

Values files passed to `helm upgrade --install` with `-f`.

They live here, **not** alongside Kubernetes manifests, because several
workflow steps apply whole directories:

```
kubectl apply -f kubernetes/argocd/
kubectl apply -f kubernetes/customers-service/
```

A Helm values file in one of those directories gets picked up by that
glob and rejected, failing the step:

```
error validating "kubernetes/argocd/argocd-values.yaml":
error validating data: [apiVersion not set, kind not set]
```

Keeping values files in their own directory makes the distinction
structural rather than something to remember.
