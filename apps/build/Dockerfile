# ================================================================================================
# === Stage 1: Build Golang API server and host for Vue app ======================================
# ================================================================================================
FROM golang:1.16-alpine as go-build
WORKDIR /build
ARG SRC_DIR=./CHANGEME

# Install system dependencies
RUN apk update && apk add git gcc musl-dev

# Fetch and cache Go modules
COPY go.mod .
COPY go.sum .
RUN go mod download

# Copy in Go source files
COPY ${SRC_DIR} .

# Now run the build
# Disabling cgo results in a fully static binary that can run without C libs
RUN GO111MODULE=on CGO_ENABLED=0 GOOS=linux go build -o server 

# ================================================================================================
# === Stage 2: Bundle server exe and Vue dist in runtime image ===================================
# ================================================================================================
FROM scratch
WORKDIR /app 

# Copy the Go server binary
COPY --from=go-build /build/server . 

EXPOSE 8080

# That's it! Just run the server 
CMD [ "./server"]