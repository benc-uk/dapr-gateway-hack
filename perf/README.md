# Cross-Network Performance Tests
- Create the test environment
```bash
./$REPO_ROOT/perf/createTestEnv.sh
```

- Create custom certificates by following the instructions in `$REPO_ROOT/sentry-config/readme.md`

- Clone the gateway Dapr fork
```bash
git clone git@github.com:jjcollinge/dapr.git
git checkout jjcollinge/gateways
```

- Build and publish the Dapr fork
```bash
export DAPR_REGISTRY="docker.io/<username>"
export DAPR_TAG="<tag>"
make build-linux
make docker-build
make docker-push
```

- Deploy custom Dapr to each cluster
```bash
helm install \
  --set-file dapr_sentry.tls.issuer.certPEM=<issuer-cert>.pem \
  --set-file dapr_sentry.tls.issuer.keyPEM=<issuer-cert>.key \
  --set-file dapr_sentry.tls.root.certPEM=<root-cert>.pem \
  --set-string global.registry=docker.io/<username> \
  --set-string global.tag=<tag> \
  --namespace dapr-system \
  dapr \
  "$PATH_TO_DAPR_FORK/charts/dapr"
```

- Deploy a gateway into each receiving cluster
```bash
kubectl apply -f "$REPO_ROOT/gateway"
```

- Build and publish the Dapr fork tests
```bash
make build-perf-app-tester
make build-perf-app-service_invocation_http
make push-perf-app-tester
make push-perf-app-service_invocation_http
```

- Update the registry and tag in the testapp to use your custom images
```bash
vim "$REPO_ROOT/perf/receiver/testapp.yaml"
```

- Deploy testapp into each receiving cluster
```bash
kubectl apply -f "$REPO_ROOT/perf/receiver/testapp.yaml"
```

- Expose the testapp as a Kubernetes services in each cluster.
```bash
kubectl expose pod testapp--... --port 3000 --target-port 3000 --type LoadBalancer
```

- Add the gateway services' external IPs to the Dapr config
```bash
vim "$REPO_ROOT/perf/sender/gateway-config.yaml"
```

- Deploy Dapr config into sender cluster
```bash
kubectl apply -f "$REPO_ROOT/perf/sender/gateway-config.yaml"
```

- Update the perf test environment file
```bash
vim "$REPO_ROOT/perf/perf.env"
```

- Source the environment file
```bash
. "$REPO_ROOT/perf.env"
```

- Navigate to the Dapr code repo.
```bash
cd "$GOPATH/src/github.com/dapr/dapr"
```

- Run service invocation perf tests.
```bash
make test-perf-service_invocation_http
```