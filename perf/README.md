# Cross-Network Performance Tests
![perf diagram](./imgs/perf.png)


The performance test defined in this document are intended to show the latency added by dapr for cross network calls. We build on dapr's existing performance test suite to run 
additional tests that route traffic across different AKS clusters. In the first instance, we run cross network calls within an Azure region. We then re-run the test against a geographically separated Azure region. A baseline call is made to try to approximate the expected network latency without dapr, so that we can better judge the impact dapr is having on the overall latency.

To run the tests, please follow the steps below.

## Running the tests

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
kubectl apply -f "$REPO_ROOT/perf/receiver"
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

- Run service invocation perf tests against the first cluster.
```bash
make test-perf-service_invocation_http
```

- Update the perf test environment file to enable the second cluster.
```bash
vim "$REPO_ROOT/perf/perf.env"
```

- Update the perf test environment file
```bash
vim "$REPO_ROOT/perf/perf.env"
```

- Source the environment file
```bash
. "$REPO_ROOT/perf.env"
```

- Run service invocation perf tests against the second cluster.
```bash
make test-perf-service_invocation_http
```