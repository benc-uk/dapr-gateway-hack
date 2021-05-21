# Deploy Sender & Receiver

Example of Kubernetes manifests to deploy sender and receiver apps

It's expected that sender is deployed into one cluster, and the receiver is deployed into a another along with the TCP gateway.

Note. The `config.yaml` file contains a [Dapr control plane configuration CRD](https://docs.dapr.io/operations/configuration/configuration-overview/#control-plane-configuration) which is currently not supported or part of the released version of Dapr. It requires a specific customized build of Dapr with several code changes, and also some modified Helm charts. It exists to support the development work and investigation of this feature.
