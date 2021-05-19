# Notes

Install with

```
kubectl apply -f .
```

The service will be of type LoadBalancer, so the external IP assigned to it, is what you need to configure in `direct_messaging.go` in the daprd code.

# mTLS Notes

You must edit `config.yaml` and paste in your custom sentry certs, at least for now :)

Hopefully fix this soon :)
