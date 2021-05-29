#!/bin/bash
set -Eeuo pipefail

# Define paths.
SCRIPT_DIR=$(dirname $(readlink -f "$0")) # Dir that contains the executing script.
REPO_ROOT="$(dirname "$SCRIPT_DIR")"      # Dir that is the root of the code repo.
STARTING_DIR=$(pwd)                       # Dir that the script was originally executed from.

# Import lib.
source "$SCRIPT_DIR/lib.sh"

# Teardown on error or term.
trap teardown ERR TERM

# Define global variables.
DAPR_PERF_DO_CREATE_ENV="${DAPR_PERF_DO_CREATE_ENV:-true}"                                           # Should the script create the environment?
DAPR_PERF_DO_BUILD_DAPR="${DAPR_PERF_DO_BUILD_DAPR:-true}"                                           # Should the script build and publish dapr?
DAPR_PERF_DO_RUN_TESTS="${DAPR_PERF_DO_RUN_TESTS:-true}"                                             # Should the script run the perf tests?
DAPR_PERF_DO_TEARDOWN="${TEARDOWN:-true}"                                                            # Should the script run teardown?
DAPR_PERF_CLUSTER_REGION="${CLUSTER1_LOCATION:-uksouth}"                                             # Azure region to host AKS cluster 1 and 2.
DAPR_PERF_CLUSTER_REMOTE_REGION="${CLUSTER1_LOCATION:-westus}"                                       # Azure region to host AKS cluster 3.
DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME:-dapr-perf-aks-1}"  # AKS cluster 1 resource group name.
DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME:-dapr-perf-aks-2}"  # AKS cluster 2 resource group name.
DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME:-dapr-perf-aks-3}"  # AKS cluster 3 resource group name.
DAPR_PERF_CLUSTER_NODE_COUNT="${DAPR_PERF_CLUSTER_NODE_COUNT:-3}"                                    # Number of nodes for AKS clusters.
DAPR_PERF_CLUSTER_NODE_SKU="${DAPR_PERF_CLUSTER_NODE_SKU:-Standard_A4_v2}"                           # AKS node SKU.
DAPR_GATEWAY_FORK_GIT_URL="${DAPR_GATEWAY_FORK_GIT_URL:-'git@github.com:jjcollinge/dapr.git'}"       # Git remote URL containing gateway code.
DAPR_GATEWAY_FORK_BRANCH="${DAPR_GATEWAY_FORK_GIT_URL:-'jjcollinge/gateways'}"                       # Git branch containing gateway code.

TMP_DIR=$(mktemp -d)                           # Temporary working directory.
CERT_DIR="$TMP_DIR/certs"                      # Temporary directory to store certificates.
FORK_DIR="$TMP_DIR/dapr"                       # Temporary directory to store local git clone.
DAPR_TAG_QUALIFIED="$DAPR_TAG-linux-amd64"     # Dapr docker image tag with build config and architecture. TODO: Determine programmatically.
mkdir -p "$CERT_DIR"

echo "Temporary working dir: $TMP_DIR"

function main() {
    validateEnvVars
    ensureAzLogin

    if [ "$DAPR_PERF_DO_CREATE_ENV" == true ]; then
        createEnv
    fi

    generateRootAndIssuerCertificates "root.conf" "issuer.conf"
    cloneDaprAndCheckoutBranch "$DAPR_GATEWAY_FORK_GIT_URL" "$DAPR_GATEWAY_FORK_BRANCH"

    if [ "$DAPR_PERF_DO_BUILD_DAPR" == true ]; then
       buildAndPublishDaprApps "$FORK_DIR"
    fi

    # Change to cluster 2 (same region receiver)
    k8sSetContext "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    installReceiverApps

    # Get loadbalancer IPs
    CLUSTER2_GW_IP=$(k8sGetLoadBalancerIP gateway)
    CLUSTER2_TESTAPP_IP=$(k8sGetLoadBalancerIP testapp)

    # Change to cluster 3 (different region receiver)
    k8sSetContext "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
    installReceiverApps 

    # Get loadbalancer IPs
    CLUSTER3_GW_IP=$(k8sGetLoadBalancerIP gateway)
    CLUSTER3_TESTAPP_IP=$(k8sGetLoadBalancerIP testapp)

    # Change to cluster 1 (sender)
    k8sSetContext "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    installSenderApps

    if [ "$DAPR_PERF_DO_RUN_TESTS" == true ]; then
        cd "$FORK_DIR"

        runSameRegionTest
        runDiffRegionTest
    fi

    teardown
}

# Run main program.
main