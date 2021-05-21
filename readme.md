# Dapr Gateway Hack Project

This repo contains some of the work required to allow Dapr to make cross network calls, e.g. from one cluster to another by the means of a TCP gateway.

This was done as part of Microsoft CSE One Week 2021, and is a proof of concept rather than a full robust implementation

Thanks to all the team, the work in this repo represents much of their efforts and input 😁

- [Joni Collinge](https://github.com/jjcollinge)
- [Shiran Rubin](https://github.com/shiranr)
- [Dariusz Parys](https://github.com/dariuszparys)
- [Avishay Balter](https://github.com/balteravishay)

## Contents

- [gateway](gateway/) - TCP proxy acting as a gateway in the receiving cluster / network
- [apps](apps/) - Sample apps to test and debug service invocation
- [deploy](deploy/) - Deploy the sample tester apps to Kubernetes in Dapr-ized mode
- [sentry-config](sentry-config/) - Configuration for mTLS within Dapr using custom certs

## Proposed High Level Architecture

![](https://user-images.githubusercontent.com/14982936/119147352-68472400-ba43-11eb-8505-bb72ef3a4621.png)
