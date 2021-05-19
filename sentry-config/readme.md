# Sentry Config

- Follow this guide https://docs.dapr.io/operations/security/mtls/#bringing-your-own-certificates

- Install `step` CLI tool and generate issuer.crt, issuer.key & ca.crt

- Init Dapr using Helm + new certs

```
helm install \
  --set-file dapr_sentry.tls.issuer.certPEM=issuer.crt \
  --set-file dapr_sentry.tls.issuer.keyPEM=issuer.key \
  --set-file dapr_sentry.tls.root.certPEM=ca.crt \
  --namespace dapr-system \
  dapr \
  dapr/dapr
```
