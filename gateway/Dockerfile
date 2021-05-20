FROM golang:1.16-alpine

RUN go get -v github.com/jpillora/go-tcp-proxy/cmd/tcp-proxy
EXPOSE 5000

ENTRYPOINT [ "tcp-proxy", "-l", "0.0.0.0:5000", "-r", "receiver:8080" ]