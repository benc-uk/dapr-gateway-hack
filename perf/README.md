# Cross-Network Performance Tests
![perf diagram](./imgs/perf.png)


The performance test defined in this document are intended to show the latency added by dapr for cross network calls. We build on dapr's existing performance test suite to run 
additional tests that route traffic across different AKS clusters. In the first instance, we run cross network calls within an Azure region. We then re-run the test against a geographically separated Azure region. A baseline call is made to try to approximate the expected network latency without dapr, so that we can better judge the impact dapr is having on the overall latency.

## Running the tests

```bash
# In the dapr gateway hack repo.
./perf/run.sh
```
## Results
Initial runs yeilded the following results:
```json
{
  "testEnv": {
    "clusters": [
      {
        "location": "uksouth",
        "nodeCount": "3",
        "nodeSku": "Standard_A4_v2"
      },
      {
        "location": "uksouth",
        "nodeCount": "3",
        "nodeSku": "Standard_A4_v2"
      },
      {
        "location": "westus",
        "nodeCount": "3",
        "nodeSku": "Standard_A4_v2"
      }
    ]
  },
  "testParams": {
    "qps": "1000",
    "connections": "16",
    "duration": "1m",
    "payloadSize": "1024",
  },
  "testResults":
  [
    {
      "testName": "SameClusterSameRegion",
      "daprVersion": "v1.1.2",
      "latencyAddedByDapr": {
        "75th": "1.95ms",
        "90th": "2.31ms"
      }
    },
    {
      "testName": "SameClusterSameRegion",
      "daprVersion": "forked",
      "latencyAddedByDapr": {
        "75th": "2.32ms",
        "90th": "3.73ms"
      },
      "latencyIncreaseOverDaprBaseline": {
        "75th": "0.37ms",
        "90th": "1.42ms",
      }
    },
    {
      "testName": "DiffClusterSameRegion",
      "daprVersion": "forked",
      "latencyAddedByNetwork": {
        "75th": "-0.03ms",
        "90th": "0.03ms"
      },
      "latencyAddedByDapr": {
        "75th": "2.80ms",
        "90th": "3.77ms"
      },
      "latencyIncreaseOverDaprBaseline": {
        "75th": "0.85ms",
        "90th": "1.46ms",
      }
    },
    {
      "testName": "DiffClusterDiffRegion",
      "daprVersion": "forked",
      "latencyAddedByNetwork": {
        "75th": "137.03ms",
        "90th": "137.62ms"
      },
      "latencyAddedByDapr": {
        "75th": "1.27ms",
        "90th": "12.09ms"
      },
      "latencyIncreaseOverDaprBaseline": {
        "75th": "-0.68ms",
        "90th": "9.78ms",
      }
    }
  ]
}
```