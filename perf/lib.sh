DAPR_PERF_CLUSTER_REGION="${CLUSTER1_LOCATION:-uksouth}"
DAPR_PERF_EXTERNAL_CLUSTER_REGION="${CLUSTER1_LOCATION:-westus}"
DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME:-dapr-perf-aks-1}"
DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME:-dapr-perf-aks-2}"
DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME:-dapr-perf-aks-3}"
DAPR_PERF_CLUSTER_NODE_COUNT="${DAPR_PERF_CLUSTER_NODE_COUNT:-3}"
DAPR_PERF_CLUSTER_NODE_SKU="${DAPR_PERF_CLUSTER_NODE_SKU:-Standard_A4_v2}"

# parameters:
# - resource group name/aks cluster name
# - location
# - aks cluster node count
# - aks cluster node sku
function createAKS {
  echo "Creating AKS cluster $1..."
  az group create -n $1 -l $2
  az aks create -n $1 -g $1 -l $2 -c $3 -s $4
  az aks get-credentials -n $1 -g $1
}

# parameters:
# - resource group name/aks cluster name
function deleteAKS {
  echo "Deleting AKS cluster $1..."
  az aks delete -y -n $1 -g $1 > /dev/null 2>&1
  az group delete -y -n $1 > /dev/null 2>&1
}

function ensureAzLogin {
    set +e
    az account get-access-token > /dev/null 2>&1
    if [[ "$?" -ne 0 ]]; then
        az login
    fi
    set -e
}

function clean {
  echo "Error! Cleaning up environment..."

  deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
  deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
  deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
}
