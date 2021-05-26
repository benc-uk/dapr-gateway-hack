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
    echo "Deleting Cross-Network Performance Test Environment."
    echo ""
    echo "----------------------------------------------------"
    echo ""
    echo "Environment 🌳:"
    echo "----------------------------------------------------"
    echo "DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
    echo ""
    echo "Starting deletion in 5 seconds ⌛..."
    echo ""
    echo "If the details above are not expected, please terminate now."
    echo -ne ""
    for i in {1..5}
    do
        echo -ne "."
        sleep 1
    done
    echo ""
    echo "Starting deletion now 🚀!"
    echo ""
}

function main {
    printHeader
    ensureAzLogin

    # Delete test environment.
    deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
}

# Run main program.
main