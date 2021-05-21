# TCP Gateway for Dapr

This is a transparent TCP reverse proxy using NGINX. This is mostly just a general purpose TCP proxy but it has a small amount of config to make it Dapr aware

The service will be of type LoadBalancer, so should get an external/public IP assigned to it, this IP will need to configured into the Dapr configuration resource as the address of the gateway, see [deploy/config.yaml](../deploy/config.yaml)

This is not the only way to deploy a gateway for cross network Dapr service invocation, and is provided as a working example.

## Deployment

Easy 😄

```bash
kubectl apply -f .
```

## Notes on Implementation

The implementation relies on a few points:

- [NGINX's stream module](http://nginx.org/en/docs/stream/ngx_stream_core_module.html) for TCP proxying.
- [NGINX's SSL pre-read module](http://nginx.org/en/docs/stream/ngx_stream_ssl_preread_module.html) which gives NGINX visibility of the TLS SNI field (i.e. the server name) _without_ the need to terminate TLS.
- Dynamic upstream hosts, based on variables.
- Some regex-fu to map the SNI server name to the Dapr service for the appropriate app being invoked.
- This implementation assumes Kubernetes is being used.

See the [nginx-conf.yaml](./nginx-conf.yaml) for details on how this was done

Although many of these points are specific to NGINX, other network proxies support similar features and could be used instead
