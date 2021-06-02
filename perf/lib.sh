#!/bin/bash

# parameters:
# - resource group name/aks cluster name
# - location
# - aks cluster node count
# - aks cluster node sku
function ensureAKS() {
  echo "Ensuring AKS cluster $1..."

  az group show -n "$1" > /dev/null 2>&1 || az group create -n "$1" -l "$2"
  az aks show -n "$1" -g "$1" > /dev/null 2>&1 || az aks create -n "$1" -g "$1" -l "$2" -c "$3" -s "$4"
  az aks get-credentials -n "$1" -g "$1" --overwrite-existing
}

# parameters:
# - resource group name/aks cluster name
function deleteAKS() {
  echo "Deleting AKS cluster $1..."

  az aks delete -y -n "$1" -g "$1" > /dev/null 2>&1
  az group delete -y -n "$1" > /dev/null 2>&1
}

function ensureAzLogin() {
  az account get-access-token > /dev/null 2>&1 || err=true
  if [ "$err" ]; then
      az login
  fi
}

# parameters:
# - kubernetes context to uses
function k8sSetContext() {
  kubectl config use-context "$1"
}

# parameters:
# - load balancer service name
function k8sGetLoadBalancerIP() {
  until [ -n "$(kubectl get svc "$1" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ]; do
    sleep 10
  done
  kubectl get svc "$1" -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

function doTeardown() {
  echo "Tearing down..."

  deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
  deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
  deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"

  rm -rf "$TMP_DIR"

  cd "$STARTING_DIR" || exit;
}

function teardown() {
  while true; do
    if [ -n "$1" ]; then
      msg="💥 Error on line $1!!"
      code=1
    else
      msg="✔ Complete!!"
      code=0
    fi

    read -rp "$msg Teardown the environment? [y/n]" yn
    case $yn in
        [Yy]* ) doTeardown; exit "$code";;
        [Nn]* ) exit "$code";;
        * ) echo "Acceptable answers are [yYnN].";;
    esac
  done
}

# parameters:
# - verb
# - noun
function printHeader() {
    echo "----------------------------------------------------"
    echo ""
    echo "         $1 Cross-Network Performance"
    echo "                 $2"
    echo ""
    echo "----------------------------------------------------"
    echo "Environment:"
    echo "----------------------------------------------------"
    echo "DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER_REGION=$DAPR_PERF_CLUSTER_REGION"
    echo "DAPR_PERF_CLUSTER_REMOTE_REGION=$DAPR_PERF_CLUSTER_REMOTE_REGION"
    echo "DAPR_PERF_CLUSTER_NODE_COUNT=$DAPR_PERF_CLUSTER_NODE_COUNT"
    echo "DAPR_PERF_CLUSTER_NODE_SKU=$DAPR_PERF_CLUSTER_NODE_SKU"
    echo ""
    echo "Starting creation in 10 seconds ⌛..."
    echo ""
    echo "If the details above are not expected, please terminate now, or press return to proceed."
    echo -ne ""
    for i in {1..10}
    do
        echo -ne "."
        sleep 1
    done
    echo ""
    echo "Buckle up, here we go 🚀!"
    echo ""
}

# parameters:
# - root certificate conf
# - issuer certificate conf
function generateRootAndIssuerCertificates() {
    echo "Generating certificates..."

    cp "$REPO_ROOT/sentry-config/root.conf" "$CERT_DIR/root.conf"
    cp "$REPO_ROOT/sentry-config/issuer.conf" "$CERT_DIR/issuer.conf"

    openssl ecparam -genkey -name prime256v1 | openssl ec -out "$CERT_DIR/root.key"
    openssl req -new -nodes -sha256 -key "$CERT_DIR/root.key" -out "$CERT_DIR/root.csr" -config "$CERT_DIR/$1" -extensions v3_req
    openssl x509 -req -sha256 -days 365 -in "$CERT_DIR/root.csr" -signkey "$CERT_DIR/root.key" -outform PEM -out "$CERT_DIR/root.pem" -extfile "$CERT_DIR/$1" -extensions v3_req
    openssl ecparam -genkey -name prime256v1 | openssl ec -out "$CERT_DIR/issuer.key"
    openssl req -new -sha256 -key "$CERT_DIR/issuer.key" -out "$CERT_DIR/issuer.csr" -config "$CERT_DIR/$2" -extensions v3_req
    openssl x509 -req -in "$CERT_DIR/issuer.csr" -CA "$CERT_DIR/root.pem" -CAkey "$CERT_DIR/root.key" -CAcreateserial -outform PEM -out "$CERT_DIR/issuer.pem" -days 365 -sha256 -extfile "$CERT_DIR/$2" -extensions v3_req
}

function installDapr() {
    echo "Installing dapr ⚙..."

    # Create dapr-system namespace if not exist.
    kubectl create ns dapr-system --dry-run=server -o yaml && \
        kubectl create ns dapr-system

    # Deploy Dapr if not exist.
    helm upgrade --install \
        --set-file dapr_sentry.tls.issuer.certPEM="$CERT_DIR/issuer.pem" \
        --set-file dapr_sentry.tls.issuer.keyPEM="$CERT_DIR/issuer.key" \
        --set-file dapr_sentry.tls.root.certPEM="$CERT_DIR/root.pem" \
        --set-string global.registry="$DAPR_REGISTRY" \
        --set-string global.tag="$DAPR_QUALIFIED_TAG" \
        --namespace dapr-system \
        dapr \
        "$FORK_DIR/charts/dapr"

    # Sleep to allow installation - avoids timeout on kubectl wait
    sleep 1

    # Wait for operator to be ready.
    kubectl wait -n dapr-system --for=condition=ready pod -l app=dapr-operator

    # Restart pods to pick up updated config.
    kubectl delete po -n dapr-system -l app=dapr-sentry
    kubectl delete po -n dapr-system -l app=dapr-placement
    kubectl delete po -n dapr-system -l app=dapr-sidecar-injector
    kubectl delete po -n dapr-system -l app=dapr-operator

    # Sleep to allow installation - avoids timeout on kubectl wait
    sleep 1

     # Wait for operator to be ready again.
    kubectl wait -n dapr-system --for=condition=ready pod -l app=dapr-operator
}

function uninstallDapr() {
    echo "Uninstalling dapr ⚙..."

    helm uninstall dapr -n dapr-system --dry-run && \
        helm uninstall dapr -n dapr-system

    kubectl delete ns dapr-system --dry-run=server && \
        kubectl delete ns dapr-system

    kubectl delete ns dapr-tests --dry-run=server && \
        kubectl delete ns dapr-tests

    kubectl delete crds components.dapr.io --dry-run && \
        kubectl delete crds components.dapr.io

    kubectl delete crds configurations.dapr.io --dry-run && \
        kubectl delete crds configurations.dapr.io

    kubectl delete crds subscriptions.dapr.io --dry-run && \
        kubectl delete crds subscriptions.dapr.io
}

function createEnv() {
    printHeader "Create" "Test Environment"

    # Create test environment.
    ensureAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
    ensureAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
    ensureAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REMOTE_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
}

function deleteEnv() {
    printHeader "Delete" "Test Environment"

    # Delete test environment.
    deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
}

function validateEnvVars() {
  if [ -z ${DAPR_REGISTRY+x} ]; then
      echo "DAPR_REGISTRY is not set!"
      exit 1
  fi

  if [ -z ${DAPR_TAG+x} ]; then
      echo "DAPR_TAG is not set!"
      exit 1
  fi
}

# parameters:
# - new test config env file
function newTestConfig() {
  cp "$SCRIPT_DIR/perf.env" "$1"
  sed -i "s|<DAPR_REGISTRY>|$DAPR_REGISTRY|g" "$1"
  sed -i "s|<DAPR_TAG>|$DAPR_QUALIFIED_TAG|g" "$1"
  source "$1"
}

# parameters:
# - test config env file
function setSameRegionConfig() {
  #sed -i "s|#export DAPR_XNET_APP_ID=testapp.default.net1|export DAPR_XNET_APP_ID=testapp.default.net1|g" "$1"
  #sed -i "s|#export DAPR_XNET_BASELINE_ENDPOINT=\"<CLUSTER2_TESTAPP_IP>:3000\"|export DAPR_XNET_BASELINE_ENDPOINT=\"$CLUSTER2_TESTAPP_IP:3000\"|g" "$1"
  export DAPR_XNET_APP_ID="testapp.default.net1"
  export DAPR_XNET_BASELINE_ENDPOINT="$CLUSTER2_TESTAPP_IP:3000"
}

# parameters:
# - test config env file
function setDiffRegionConfig() {
  #sed -i "s|#export DAPR_XNET_APP_ID=testapp.default.net2|export DAPR_XNET_APP_ID=testapp.default.net2|g" "$1"
  #sed -i "s|#export DAPR_XNET_BASELINE_ENDPOINT=\"<CLUSTER3_TESTAPP_IP>:3000\"|export DAPR_XNET_BASELINE_ENDPOINT=\"$CLUSTER3_TESTAPP_IP:3000\"|g" "$1"
  export DAPR_XNET_APP_ID="testapp.default.net2"
  export DAPR_XNET_BASELINE_ENDPOINT="$CLUSTER3_TESTAPP_IP:3000"
}

function runSameRegionTest() {
  cd "$FORK_DIR"

  newTestConfig "$TMP_DIR/perf.env"
  setSameRegionConfig

  make test-perf-service_invocation_http
}

function runDiffRegionTest() {
  cd "$FORK_DIR"

  newTestConfig "$TMP_DIR/perf.env"
  setDiffRegionConfig

  make test-perf-service_invocation_http
}

function installZipkin() {
  kubectl create deployment zipkin --image openzipkin/zipkin --dry-run=server -o yaml || err=true
  if [ ! "$err" ]; then
    kubectl create deployment zipkin --image openzipkin/zipkin
    kubectl expose deployment zipkin --type ClusterIP --port 9411
  fi
}

function uninstallZipkin() {
  kubectl delete deployment zipkin --dry-run=server -o yaml || err=true
  if [ ! "$err" ]; then
    kubectl delete deployment zipkin
  fi
}

function installGateway() {
  kubectl apply -f "$REPO_ROOT/gateway"
  kubectl delete po -l app=gateway
}

function installTestApp() {
  kubectl apply -f "$TMP_DIR/testapp.yaml"
  kubectl delete po -l app=testapp
  kubectl apply -f "$SCRIPT_DIR/receiver/testapp-svc.yaml"
}

function installReceiverApps() {
  # Update app definitions.
  cp "$SCRIPT_DIR/receiver/testapp.yaml" "$TMP_DIR"
  sed -i "s|<INSERT_CUSTOM_REGISTRY>|$DAPR_REGISTRY|g" "$TMP_DIR/testapp.yaml"
  sed -i "s|<INSERT_CUSTOM_TAG>|$DAPR_QUALIFIED_TAG|g" "$TMP_DIR/testapp.yaml"

  # Install apps.
  installDapr
  installZipkin
  installGateway
  installTestApp
}

function installSenderApps() {
  installDapr
  installGatewayDaprConfig
  installZipkin
}

function installGatewayDaprConfig() {
  kubectl create ns dapr-tests --dry-run=server -o yaml && \
      kubectl create ns dapr-tests

  cp "$SCRIPT_DIR/sender/gateway-config.yaml" "$TMP_DIR"
  sed -i "s|<CLUSTER2_GW_SVC>|$CLUSTER2_GW_IP|g" "$TMP_DIR/gateway-config.yaml"
  sed -i "s|<CLUSTER3_GW_SVC>|$CLUSTER3_GW_IP|g" "$TMP_DIR/gateway-config.yaml"
  kubectl apply -f "$TMP_DIR/gateway-config.yaml"
}

# parameters:
# - dapr fork git url
# - git branch
function cloneDaprAndCheckoutBranch() {
  cd "$TMP_DIR"

  git clone "$1" dapr || true
  cd dapr
  git checkout "$2"

  cd "$TMP_DIR"
}

# parameters:
# - dapr directory
function buildAndPublishDaprApps() {
  cd "$FORK_DIR"

  # Build and publish the dapr fork.
  make build-linux
  make docker-build
  make docker-push

  # Build and publish the test for dapr fork.
  make build-perf-app-tester
  make build-perf-app-service_invocation_http
  make push-perf-app-tester
  make push-perf-app-service_invocation_http

  cd "$TMP_DIR"
}