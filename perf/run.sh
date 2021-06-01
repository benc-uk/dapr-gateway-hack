#!/bin/bash
# shellcheck disable=SC2034
# SC2034: Var appears unused. Verify use (or export if used externally)

set -Eeox pipefail

# Define paths.
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")  # Dir that contains the executing script.
REPO_ROOT="$(dirname "$SCRIPT_DIR")"         # Dir that is the root of the code repo.
STARTING_DIR=$(pwd)                          # Dir that the script was originally executed from.

# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

# Teardown on error.
trap 'teardown $LINENO' ERR

# Define global variables.
DAPR_PERF_DO_CREATE_ENV="${DAPR_PERF_DO_CREATE_ENV:-true}"                                           # Should the script create the environment?
DAPR_PERF_DO_BUILD_DAPR="${DAPR_PERF_DO_BUILD_DAPR:-true}"                                           # Should the script build and publish dapr?
DAPR_PERF_DO_RUN_TESTS="${DAPR_PERF_DO_RUN_TESTS:-true}"                                             # Should the script run the perf tests?
DAPR_PERF_CLUSTER_REGION="${CLUSTER1_LOCATION:-uksouth}"                                             # Azure region to host AKS cluster 1 and 2.
DAPR_PERF_CLUSTER_REMOTE_REGION="${CLUSTER1_LOCATION:-westus}"                                       # Azure region to host AKS cluster 3.
DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME:-dapr-perf-aks-1}"  # AKS cluster 1 resource group name.
DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME:-dapr-perf-aks-2}"  # AKS cluster 2 resource group name.
DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME="${DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME:-dapr-perf-aks-3}"  # AKS cluster 3 resource group name.
DAPR_PERF_CLUSTER_NODE_COUNT="${DAPR_PERF_CLUSTER_NODE_COUNT:-3}"                                    # Number of nodes for AKS clusters.
DAPR_PERF_CLUSTER_NODE_SKU="${DAPR_PERF_CLUSTER_NODE_SKU:-Standard_A4_v2}"                           # AKS node SKU.
DAPR_GIT_URL="${DAPR_GIT_URL:-git@github.com:jjcollinge/dapr.git}"                                   # Git remote URL containing gateway code.
DAPR_GIT_BRANCH="${DAPR_GIT_BRANCH:-jjcollinge/gateways}"                                            # Git branch containing gateway code.

# Set the dapr test build tag to the same as the dapr build tag.
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DAPR_QUALIFIED_TAG="$DAPR_TAG-linux-amd64"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    DAPR_QUALIFIED_TAG="$DAPR_TAG-darwin-amd64"
else
    echo "Unsupported platform $OSTYPE"
    exit 1
fi
DAPR_TEST_TAG="$DAPR_QUALIFIED_TAG"

# Create working directories.
TMP_DIR=$(mktemp -d)                           # Temporary working directory.
CERT_DIR="$TMP_DIR/certs"                      # Temporary directory to store certificates.
FORK_DIR="$TMP_DIR/dapr"                       # Temporary directory to store local git clone.
mkdir -p "$CERT_DIR"
echo "Temporary working dir: $TMP_DIR"

function main() {
    validateEnvVars
    ensureAzLogin

    # Create the test environment. This includes 3 AKS
    # clusters, 2 in the same region and 1 in a different
    # region.
    if [ "$DAPR_PERF_DO_CREATE_ENV" == true ]; then
        createEnv
    fi

    # Generate root and issuer CA certificates for Dapr + Sentry
    # to use for internal mTLS. These certificates will be used
    # as across each cluster to ensure cross cluster mTLS is verified.
    generateRootAndIssuerCertificates "root.conf" "issuer.conf"

    # Clone and checkout a specific version of Dapr. This will be the
    # version we build, push and deploy with using the Helm charts.
    cloneDaprAndCheckoutBranch "$DAPR_GIT_URL" "$DAPR_GIT_BRANCH"
    if [ "$DAPR_PERF_DO_BUILD_DAPR" == true ]; then
       buildAndPublishDaprApps "$FORK_DIR"
    fi

    # Change Kubernetes context to cluster 2 (same region receiver)
    # and install all the required receiver apps.
    k8sSetContext "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    installReceiverApps
    # Get loadbalancer IPs for cluster 2 services.
    CLUSTER2_GW_IP=$(k8sGetLoadBalancerIP gateway)
    CLUSTER2_TESTAPP_IP=$(k8sGetLoadBalancerIP testapp)

    # Change Kubernetes context to cluster 3 (different region receiver)
    # and install all the required receiver apps.
    k8sSetContext "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
    installReceiverApps 
    # Get loadbalancer IPs for cluster 3 services.
    CLUSTER3_GW_IP=$(k8sGetLoadBalancerIP gateway)
    CLUSTER3_TESTAPP_IP=$(k8sGetLoadBalancerIP testapp)

    # Change Kubernetes context to cluster 1 (sender)
    # and install all the required sender apps.
    k8sSetContext "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    installSenderApps

    if [ "$DAPR_PERF_DO_RUN_TESTS" == true ]; then
        cd "$FORK_DIR"

        # Run the perf tests across the 2 AKS
        # clusters in the same region
        runSameRegionTest

        # Run the perf tests across the 2 AKS
        # clusters in different regions.
        runDiffRegionTest
    fi

    teardown
}

# Run main program.
main