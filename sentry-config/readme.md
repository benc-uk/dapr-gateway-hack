# Sentry Config

- Follow this guide https://docs.dapr.io/operations/security/mtls/#bringing-your-own-certificates

- Install `step` CLI tool and generate issuer.crt, issuer.key & ca.crt

- Init Dapr using Helm + new certs

```bash
helm install \
  --set-file dapr_sentry.tls.issuer.certPEM=issuer.pem \
  --set-file dapr_sentry.tls.issuer.keyPEM=issuer.key \
  --set-file dapr_sentry.tls.root.certPEM=root.pem \
  --set global.registry=docker.io/avbalter \
  --set global.tag=cseoneweek-linux-amd64 \
  --namespace dapr-system \
  dapr \
  dapr/dapr
```
