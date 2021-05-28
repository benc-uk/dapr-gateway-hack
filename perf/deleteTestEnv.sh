#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR=$(dirname $(readlink -f "$0"))

# Import lib.
source "$SCRIPT_DIR/lib.sh"

# Clean on error.
trap teardownEnv ERR TERM

function printHeader() {
    echo "----------------------------------------------------"
    echo ""
    echo "         Deleting Cross-Network Performance"
    echo "                 Test Environment"
    echo ""
    echo "----------------------------------------------------"
    echo "Environment 🌳:"
    echo "----------------------------------------------------"
    echo "DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    echo "DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME=$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
    echo ""
    echo "Starting deletion in 10 seconds ⌛..."
    echo ""
    echo "If the details above are not expected, please terminate now."
    echo -ne ""
    for i in {1..10}
    do
        echo -ne "."
        sleep 1
    done
    echo ""
    echo "Starting deletion now 🚀!"
    echo ""
}

function main() {
    printHeader
    ensureAzLogin

    # Delete test environment.
    deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
}

# Run main program.
main