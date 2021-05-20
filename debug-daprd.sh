#!/bin/bash

# Wrapper script for running & debugging daprd in telepresence

for varName in CERT_PATH APP_ID PROJ_PATH; do
  varVal=$(eval echo "\${$varName}")
  [[ -z $varVal ]] && { echo "💥 Error! Required variable '$varName' is not set!"; varUnset=true; }
done
[[ $varUnset ]] && exit 1

export DAPR_TRUST_ANCHORS=$(cat "$CERT_PATH/ca.crt" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')
export DAPR_CERT_CHAIN=$(cat "$CERT_PATH/issuer.crt" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')
export DAPR_CERT_KEY=$(cat "$CERT_PATH/issuer.key" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')

export NAMESPACE=${NAMESPACE:-default}
export SENTRY_LOCAL_IDENTITY=${SENTRY_LOCAL_IDENTITY:-default:default}

"$PROJ_PATH"/dist/linux_amd64/release/daprd \
  --enable-mtls \
  --app-id "$APP_ID" \
  --mode kubernetes \
  --dapr-http-port 3500 \
  --dapr-grpc-port 50000 \
  --dapr-internal-grpc-port 50002 \
  --control-plane-address dapr-api.dapr-system.svc.cluster.local:80 \
  --placement-host-address dapr-placement.dapr-system.svc.cluster.local:50005 \
  --sentry-address dapr-sentry.dapr-system.svc.cluster.local:80 \
  --log-level debug \
  --metrics-port 9099
