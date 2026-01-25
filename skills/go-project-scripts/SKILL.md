---
name: go-project-scripts
description: Build scripts, Dockerfile, Docker Compose, and deployment configurations for Go projects
---

# Build & Deployment Scripts

## Directory Structure

```
scripts/
├── build.sh          # Cross-platform build script
├── Dockerfile        # Multi-stage Docker build
├── entrypoint.sh     # Container entrypoint with env support
└── compose.yaml      # Docker Compose for local deployment
```

## Build Script (scripts/build.sh)

```sh
#!/bin/sh

set -e

cd "$(dirname "$0")/../"

OS=$(uname -s)

# Determine output binary name
case "$OS" in
  *CYGWIN*|*MINGW*|*MSYS*)
    OUTPUT="./build/memos.exe"
    ;;
  *)
    OUTPUT="./build/memos"
    ;;
esac

echo "Building for $OS..."

# Ensure build directories exist
mkdir -p ./build/.gocache ./build/.gomodcache
export GOCACHE="$(pwd)/build/.gochache"
export GOMODCACHE="$(pwd)/build/.gomodcache"

# Build the executable
go build -o "$OUTPUT" ./cmd/server

echo "Build successful: $OUTPUT"
```

## Dockerfile (Multi-Stage Build)

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS backend
WORKDIR /backend-build

RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

ARG TARGETOS TARGETARCH VERSION COMMIT
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build \
      -trimpath \
      -ldflags="-s -w -extldflags '-static'" \
      -tags netgo,osusergo \
      -o server \
      ./cmd/server

# Minimal runtime image
FROM alpine:3.21 AS monolithic

RUN apk add --no-cache tzdata ca-certificates && \
    addgroup -g 10001 -S nonroot && \
    adduser -u 10001 -S -G nonroot -h /var/opt/myapp nonroot && \
    mkdir -p /var/opt/myapp && \
    chown -R nonroot:nonroot /var/opt/myapp

COPY --from=backend /backend-build/server /usr/local/myapp/server
COPY --from=backend --chmod=755 /scripts/entrypoint.sh /usr/local/myapp/entrypoint.sh

USER nonroot:nonroot
WORKDIR /var/opt/myapp

VOLUME /var/opt/myapp
ENV TZ="UTC"
EXPOSE 8080

ENTRYPOINT ["/usr/local/myapp/entrypoint.sh", "/usr/local/myapp/server"]
```

## Entrypoint (scripts/entrypoint.sh)

```sh
#!/usr/bin/env sh

# Support for env files from secrets
file_env() {
    var="$1"
    fileVar="${var}_FILE"

    val_var="$(printenv "$var")"
    val_fileVar="$(printenv "$fileVar")"

    if [ -n "$val_var" ] && [ -n "$val_fileVar" ]; then
        echo "error: both $var and $fileVar are set (exclusive)" >&2
        exit 1
    fi

    if [ -n "$val_var" ]; then
        val="$val_var"
    elif [ -n "$val_fileVar" ]; then
        if [ ! -r "$val_fileVar" ]; then
            echo "error: file '$val_fileVar' not readable" >&2
            exit 1
        fi
        val="$(cat "$val_fileVar")"
    fi

    export "$var"="$val"
    unset "$fileVar"
}

# Load env vars (supports *_FILE pattern for secrets)
file_env "MEMOS_DSN"  # or your app's env var

exec "$@"
```

## Docker Compose (scripts/compose.yaml)

```yaml
services:
  myapp:
    image: myapp:latest
    container_name: myapp
    volumes:
      - ~/.myapp:/var/opt/myapp
    ports:
      - "8080:8080"
    environment:
      - MODE=prod
      - DRIVER=sqlite
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `MODE` | dev/demo/prod |
| `DRIVER` | sqlite/mysql/postgres |
| `DSN` | Database connection string |
| `PORT` | HTTP listen port |
| `DATA` | Data directory |
| `*{VAR}_FILE` | Load from file (for secrets) |

## Build & Run

```bash
# Local build
./scripts/build.sh
./build/server

# Docker build
docker build -t myapp:latest -f scripts/Dockerfile .

# Docker run
docker run -p 8080:8080 -v ~/.myapp:/var/opt/myapp myapp:latest

# Docker Compose
docker compose -f scripts/compose.yaml up -d
```

## Key Patterns

| Pattern | Description |
|---------|-------------|
| Multi-stage build | Minimal runtime image |
| Non-root user | Security best practice |
| ENV_FILE support | Secrets from mounted files |
| Volume for data | Persist database |
| Static binary | CGO_ENABLED=0 for portability |
