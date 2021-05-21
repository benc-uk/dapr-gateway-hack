# Sender & Receiver Apps

These are a pair of simple HTTP sender and receiver apps written in Go designed for testing & debugging Dapr service invocation

- The sender makes regular HTTP GET requests via [the Dapr service invocation API](https://docs.dapr.io/reference/api/service_invocation_api/#http-request) every few seconds
- The receiver is simply a HTTP server listening for requests at a given path, and logging them

# Usage

Set `IMAGE_REG`, `IMAGE_REPO` and `IMAGE_TAG` when calling make to point to your own registry and container repo prefix

```
$ make
help                 💬 This help message :)
image-receiver       📦 Build receiver container image from Dockerfile
image-sender         📦 Build sender container image from Dockerfile
push-receiver        📤 Push receiver container image to registry
push-sender          📤 Push sender container image to registry
run-receiver         🏃‍ Run receiver locally using Go
run-sender           🏃‍ Run sender locally using Go
```

# Config

All config is set with environmental variables

## Sender

| Variable       | Purpose                                                                                                    | Default  |
| -------------- | ---------------------------------------------------------------------------------------------------------- | -------- |
| REMOTE_APP_ID  | Dapr app-id to try to invoke                                                                               | receiver |
| REMOTE_METHOD  | Method to invoke                                                                                           | echo     |
| INTERVAL       | How frequently to make the call                                                                            | 5        |
| DAPR_HTTP_PORT | Typically you should never set this, as it will be set by the Dapr wrapping process (sidecar or local CLI) | 3500     |

## Receiver

| Variable  | Purpose                                                                                  | Default |
| --------- | ---------------------------------------------------------------------------------------- | ------- |
| PORT      | HTTP port to listen on                                                                   | 8080    |
| HTTP_PATH | URL path to accept requests on                                                           | /echo   |
| DUMP      | If set to `true` the full HTTP request will be dumped into the log, with header and body | `false` |

# Running Dapr-ized locally

Start the sender with daprd process "sidecar", it should start throwing HTTP 500 errors until the receiver is started

```bash
dapr run --app-id sender make run-sender
```

Start receiver also Dapr-ized

```bash
dapr run --app-id receiver --app-port 8080 make run-receiver
```
