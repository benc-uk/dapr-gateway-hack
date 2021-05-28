DAPR_PERF_CLUSTER_REGION="${CLUSTER1_LOCATION:-uksouth}"
DAPR_PERF_EXTERNAL_CLUSTER_REGION="${CLUSTER1_LOCATION:-westus}"
DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME:-dapr-perf-aks-1}"
DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME:-dapr-perf-aks-2}"
DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME:-dapr-perf-aks-3}"
DAPR_PERF_CLUSTER_NODE_COUNT="${DAPR_PERF_CLUSTER_NODE_COUNT:-3}"
DAPR_PERF_CLUSTER_NODE_SKU="${DAPR_PERF_CLUSTER_NODE_SKU:-Standard_A4_v2}"
TEARDOWN="${TEARDOWN:-true}"
PWD=$(pwd)

# parameters:
# - resource group name/aks cluster name
# - location
# - aks cluster node count
# - aks cluster node sku
function createAKS() {
  echo "Creating AKS cluster $1..."
  az group create -n $1 -l $2
  az aks create -n $1 -g $1 -l $2 -c $3 -s $4
  
  az aks get-credentials -n $1 -g $1
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

function teardownEnv() {
  if [ "$TEARDOWN" == true ]; then
    echo "Tearing down env..."
    deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
  fi
}
