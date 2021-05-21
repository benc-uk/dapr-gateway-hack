# Dapr Gateway Hack Project

This repo contains some of the work required to allow Dapr to make cross network calls, e.g. from one cluster to another by the means of a TCP gateway.

This was done as part of Microsoft CSE One Week 2021, and is a proof of concept rather than a full robust implementation

Thanks to the team 😁

- @jjcollinge
- @shiranr
- @dariuszparys
- @balteravishay

## Contents

- [gateway](gateway/) - TCP proxy acting as a gateway in the receiving cluster / network
- [apps](apps/) - Sample apps to test and debug service invocation
- [deploy](deploy/) - Deploy the sample apps to Kubernetes in Dapr-ized mode
- [sentry-config](sentry-config/) - Configuration for mTLS within Dapr using custom certs
