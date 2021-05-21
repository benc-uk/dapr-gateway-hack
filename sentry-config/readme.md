# Sentry Config

For the cross gateway calls to work both clusters must be configured to use the same mTLS certs.  
This is handled by a component called Sentry

Note. Since Go 1.15 the certs must contain a SAN extension field, this doc contains the commands and steps to generate a working set of certs with a valid SAN field

### Generate Root CA: key, CSR and cert

```bash
openssl ecparam -genkey -name prime256v1 | openssl ec -out root.key
openssl req -new -nodes -sha256 -key root.key -out root.csr -config root.conf -extensions v3_req
openssl x509 -req -sha256 -days 365 -in root.csr -signkey root.key -outform PEM -out root.pem -extfile root.conf -extensions v3_req
```

### Generate Issuer: key, CSR and cert

```bash
openssl ecparam -genkey -name prime256v1 | openssl ec -out issuer.key
openssl req -new -sha256 -key issuer.key -out issuer.csr -config issuer.conf -extensions v3_req
openssl x509 -req -in issuer.csr -CA root.pem -CAkey root.key -CAcreateserial -outform PEM -out issuer.pem -days 365 -sha256 -extfile issuer.conf -extensions v3_req
```

### Deploy Dapr using Helm + new certs

This assumes you are deploying a custom build of dapr which has been pushed to a Docker registry

```bash
helm install \
  --set-file dapr_sentry.tls.issuer.certPEM=issuer.pem \
  --set-file dapr_sentry.tls.issuer.keyPEM=issuer.key \
  --set-file dapr_sentry.tls.root.certPEM=root.pem \
  --set global.registry=__CHANGE_ME__ \
  --set global.tag=__CHANGE_ME__ \
  --namespace dapr-system \
  dapr \
  dapr/dapr
```
