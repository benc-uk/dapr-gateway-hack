# TCP Gateway for Dapr

This is a transparent TCP reverse proxy using NGINX. This is mostly just a general purpose TCP proxy but it has a small amount of config

The service will be of type LoadBalancer, so the external IP assigned to it, is what you need to configure in `direct_messaging.go` in the daprd code.

## Install

Install with

```
kubectl apply -f .
```
