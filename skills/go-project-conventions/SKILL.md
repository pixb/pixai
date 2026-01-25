---
name: go-project-conventions
description: Code conventions including error handling, imports, linting, common commands, and workflows
---

# Code Conventions

## Error Handling
- Use `errors.Wrap(err, "context")` from `github.com/pkg/errors`
- Use `status.Errorf(codes.NotFound, "message")` for gRPC errors
- Use `connect.NewError(connect.Code, err)` for Connect RPC errors
- **Forbidden**: `fmt.Errorf`, `ioutil.ReadDir`

## Imports
```go
import (
    // stdlib
    "context"
    "fmt"
    "net/http"
    "time"

    // third-party
    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"
    "github.com/pkg/errors"
    "connectrpc.com/connect"
    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"

    // local - use your project path
    "github.com/usememos/memos/internal/profile"
    "github.com/usememos/memos/server"
    "github.com/usememos/memos/server/auth"
    "github.com/usememos/memos/store"
)
```
- Group: stdlib, third-party, local
- Sort alphabetically within groups
- Use `goimports -w .`

## Linting
- Tool: `golangci-lint` (`.golangci.yaml`)
- Formatter: `goimports`
- Linters: revive, govet, staticcheck, misspell, gocritic, godot

## Common Commands

```bash
# Dev server
go run ./cmd/memos --mode dev --port 8081

# Tests
go test ./...
go test -run TestName ./path/...
go test -cover ./...

# Lint & Format
golangci-lint run
goimports -w .

# Proto
cd proto && buf generate && buf lint
```

## Workflows

### Add API Endpoint
1. Create `proto/api/v1/{service}_service.proto`
   - Define request/response messages
   - Add RPC method with `google.api.http` annotation
2. Run `cd proto && buf generate`
3. Create `server/router/api/v1/{service}_service.go`
   - Implement service struct with store dependency
   - Implement Connect RPC handler methods
4. Register in `server/router/api/v1/v1.go`
   - Add to gRPC server: `v1pb.Register{Service}Server`
   - Add gRPC-Gateway handler: `{Service}HandlerFromEndpoint`
5. Add to `acl_config.go` if public endpoint
6. Add frontend hook in `web/src/hooks/`

### Add Database Model
1. Create `store/migration/{driver}/{version}/NN__description.sql`
2. Update `store/migration/{driver}/LATEST.sql`
3. Update `store/driver.go` interface
4. Implement in `store/db/{driver}/*.go`
5. Add to `store/store.go` if caching needed
6. Add model in `store/{model}.go`

### Run Tests Against Multiple Databases
```bash
# SQLite (default)
DRIVER=sqlite go test ./...

# MySQL
DRIVER=mysql DSN="user:pass@tcp(localhost:3306)/memos" go test ./...

# PostgreSQL
DRIVER=postgres DSN="postgres://user:pass@localhost:5432/memos?sslmode=disable" go test ./...
```
