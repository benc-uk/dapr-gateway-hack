```
dapr run --app-id receiver --app-port 8080 go run receiver/main.go
```

```
export REMOTE_APP_ID=receiver
dapr run --app-id sender go run sender/main.go
```
