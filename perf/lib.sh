# parameters:
# - resource group name/aks cluster name
# - location
# - aks cluster node count
# - aks cluster node sku
function createAKS() {
  echo "Creating AKS cluster $1..."
  az group create -n $1 -l $2
  az aks create -n $1 -g $1 -l $2 -c $3 -s $4
  
  az aks get-credentials -n $1 -g $1 --overwrite-existing
}

# parameters:
# - resource group name/aks cluster name
function deleteAKS() {
  echo "Deleting AKS cluster $1..."

  az aks delete -y -n $1 -g $1 > /dev/null 2>&1
  az group delete -y -n $1 > /dev/null 2>&1
}

function ensureAzLogin() {
  set +e
  az account get-access-token > /dev/null 2>&1
  if [[ "$?" -ne 0 ]]; then
      az login
  fi
  set -e
}

# parameters:
# - kubernetes context to uses
function k8sSetContext() {
  kubectl config use-context "$1"
}

# parameters:
# - load balancer service name
function k8sGetLoadBalancerIP() {
  until [ -n "$(kubectl get svc $1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ]; do
    sleep 10
  done
  echo $(kubectl get svc $1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
}

function teardown() {
  if [ "$DAPR_PERF_DO_TEARDOWN" == true ]; then
    echo "Tearing down..."

    deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"

    rm -rf "$TMP_DIR"
  fi
  
  cd "$STARTING_DIR"
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
    echo "Environment 🌳:"
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
    echo "If the details above are not expected, please terminate now."
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

    PWD=$(pwd)

    cd "$CERT_DIR"
    cp "$REPO_ROOT/sentry-config/root.conf" "$CERT_DIR/root.conf"
    cp "$REPO_ROOT/sentry-config/issuer.conf" "$CERT_DIR/issuer.conf"

    openssl ecparam -genkey -name prime256v1 | openssl ec -out root.key
    openssl req -new -nodes -sha256 -key root.key -out root.csr -config $1 -extensions v3_req
    openssl x509 -req -sha256 -days 365 -in root.csr -signkey root.key -outform PEM -out root.pem -extfile $1 -extensions v3_req
    openssl ecparam -genkey -name prime256v1 | openssl ec -out issuer.key
    openssl req -new -sha256 -key issuer.key -out issuer.csr -config $2 -extensions v3_req
    openssl x509 -req -in issuer.csr -CA root.pem -CAkey root.key -CAcreateserial -outform PEM -out issuer.pem -days 365 -sha256 -extfile $2 -extensions v3_req
  
    cd "$PWD"
}

function installDapr() {
    echo "Installing dapr..."

    # Create dapr-system namespace if not exist.
    kubectl create ns dapr-system --dry-run=server -o yaml && \
        kubectl create ns dapr-system

    # Deploy Dapr if not exist.
    helm upgrade --install \
        --set-file dapr_sentry.tls.issuer.certPEM="$CERT_DIR/issuer.pem" \
        --set-file dapr_sentry.tls.issuer.keyPEM="$CERT_DIR/issuer.key" \
        --set-file dapr_sentry.tls.root.certPEM="$CERT_DIR/root.pem" \
        --set-string global.registry="$DAPR_REGISTRY" \
        --set-string global.tag="$DAPR_TAG_QUALIFIED" \
        --namespace dapr-system \
        dapr \
        "$FORK_DIR/charts/dapr"

    # Wait for operator to be ready.
    kubectl wait -n dapr-system --for=condition=ready pod -l app=dapr-operator

    # Restart pods to pick up updated config.
    kubectl delete po -n dapr-system -l app=dapr-sentry
    kubectl delete po -n dapr-system -l app=dapr-placement
    kubectl delete po -n dapr-system -l app=dapr-sidecar-injector
    kubectl delete po -n dapr-system -l app=dapr-operator

     # Wait for operator to be ready again.
    kubectl wait -n dapr-system --for=condition=ready pod -l app=dapr-operator
}

function uninstallDapr() {
    echo "Uninstalling dapr..."

    helm uninstall dapr -n dapr-system --dry-run && \
        helm uninstall dapr -n dapr-system

    kubectl delete ns dapr-system --dry-run=server && \
        kubectl delete ns dapr-system

    kubectl delete ns dapr-tests --dry-run=server && \
        kubectl delete ns dapr-tests
}

function createEnv() {
    printHeader "Create" "Test Environment"

    # Create test environment.
    createAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
    createAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
    createAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REMOTE_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
}

function deleteEnv() {
    printHeader "Create" "Test Environment"

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
  cp "$SCRIPT_DIR/perf.env" $1
  sed -i "s|<DAPR_REGISTRY>|$DAPR_REGISTRY|g" "$1"
  sed -i "s|<DAPR_TAG>|$DAPR_TAG|g" "$1"
}

# parameters:
# - test config env file
function setSameRegionConfig() {
  sed -i "s|#export DAPR_XNET_APP_ID=testapp.default.net1|export DAPR_XNET_APP_ID=testapp.default.net1|g" "$1"
  sed -i "s|#export DAPR_XNET_BASELINE_ENDPOINT=\"<CLUSTER2_TESTAPP_IP>:3000\"|export DAPR_XNET_BASELINE_ENDPOINT=\"$CLUSTER2_TESTAPP_IP:3000\"|g" "$1"
}

# parameters:
# - test config env file
function setDiffRegionConfig() {
  sed -i "s|#export DAPR_XNET_APP_ID=testapp.default.net2|export DAPR_XNET_APP_ID=testapp.default.net2|g" "$1"
  sed -i "s|#export DAPR_XNET_BASELINE_ENDPOINT=\"<CLUSTER3_TESTAPP_IP>:3000\"|export DAPR_XNET_BASELINE_ENDPOINT=\"$CLUSTER3_TESTAPP_IP:3000\"|g" "$1"
}

function loadSameRegionTestConfig() {
  newTestConfig "$TMP_DIR/xnet-perf.env"
  setSameRegionConfig "$TMP_DIR/xnet-perf.env"
  
  source "$TMP_DIR/xnet-perf.env"
}

function loadDiffRegionTestConfig() {
  newTestConfig "$TMP_DIR/net-perf.env"
  setSameRegionConfig "$TMP_DIR/net-perf.env"
  
  source "$TMP_DIR/net-perf.env"
}

function runSameRegionTest() {
  cd "$FORK_DIR"

  loadSameRegionTestConfig
  make test-perf-service_invocation_http
}

function runDiffRegionTest() {
  cd "$FORK_DIR"

  loadDiffRegionTestConfig
  make test-perf-service_invocation_http
}

function installZipkin() {
  kubectl create deployment zipkin --image openzipkin/zipkin --dry-run=server -o yaml && \
        kubectl create deployment zipkin --image openzipkin/zipkin
}

function uninstallZipkin() {
  kubectl delete deployment zipkin --dry-run=server -o yaml && \
        kubectl delete deployment zipkin
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
  sed -i "s|<INSERT_CUSTOM_TAG>|$DAPR_TAG_QUALIFIED|g" "$TMP_DIR/testapp.yaml"

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
  PWD=$(pwd)

  git clone $1 dapr
  cd dapr
  git checkout $2

  cd "$PWD"
}

# parameters:
# - dapr directory
function buildAndPublishDaprApps() {
  PWD=$(pwd)

  cd "$1"

  # Build and publish the dapr fork.
  make build-linux
  make docker-build
  make docker-push

  # Build and publish the test for dapr fork.
  make build-perf-app-tester
  make build-perf-app-service_invocation_http
  make push-perf-app-tester
  make push-perf-app-service_invocation_http

  cd "$PWD"
}