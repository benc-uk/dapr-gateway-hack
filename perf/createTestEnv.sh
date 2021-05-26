#!/bin/bash
set -e

SCRIPT_DIR=$(dirname "$0")

# Import lib.
source "$SCRIPT_DIR/lib.sh"

# Clean on error.
trap clean ERR

function printHeader {
    echo "----------------------------------------------------"
    echo ""
    echo "Creating Cross-Network Performance Test Environment."
    echo ""
    echo "----------------------------------------------------"
    echo ""
    echo "Environment 🌳:"
    echo "----------------------------------------------------"
    echo "DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER_REGION=$DAPR_PERF_CLUSTER_REGION"
    echo "DAPR_PERF_EXTERNAL_CLUSTER_REGION=$DAPR_PERF_EXTERNAL_CLUSTER_REGION"
    echo "DAPR_PERF_CLUSTER_NODE_COUNT=$DAPR_PERF_CLUSTER_NODE_COUNT"
    echo "DAPR_PERF_CLUSTER_NODE_SKU=$DAPR_PERF_CLUSTER_NODE_SKU"
    echo ""
    echo "Starting creation in 5 seconds ⌛..."
    echo ""
    echo "If the details above are not expected, please terminate now."
    echo -ne ""
    for i in {1..5}
    do
        echo -ne "."
        sleep 1
    done
    echo ""
    echo "Starting creation now 🚀!"
    echo ""
}

function main {
    printHeader
    ensureAzLogin

    # Create test environment.
    createAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
    createAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME" "$DAPR_PERF_CLUSTER_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
    createAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME" "$DAPR_PERF_EXTERNAL_CLUSTER_REGION" "$DAPR_PERF_CLUSTER_NODE_COUNT" "$DAPR_PERF_CLUSTER_NODE_SKU"
}

# Run main program.
main