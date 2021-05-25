#!/bin/bash
set -e

# Import lib.
source ./lib.sh

# Clean on error.
trap clean ERR

function main {
    ensureAzLogin

    # Delete test environment.
    deleteAKS "$DAPR_PERF_CLUSTER1_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER2_RESOURCE_GROUP_NAME"
    deleteAKS "$DAPR_PERF_CLUSTER3_RESOURCE_GROUP_NAME"
}

# Run main program.
main