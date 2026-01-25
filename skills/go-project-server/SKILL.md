---
name: go-project-server
description: Server implementation with Echo, Connect RPC interceptors, dual protocol registration (HTTP + gRPC), cmux port reuse, and authentication module
---

# Server Implementation

## ⚠️ CRITICAL: This Goes in server/server.go

**NOT in main.go!**

All server code belongs in `server/server.go`:
- Echo initialization
- cmux port multiplexing
- Service registration
- Route handlers
- Shutdown logic

`main.go` should ONLY call `server.Start()` and `server.Shutdown()`.

## Prerequisites

**IMPORTANT**: Server layer depends on generated proto code. You MUST create proto files and generate code FIRST:

```bash
# 1. Create proto directory and definitions (see go-project-proto)
mkdir -p proto/api/v1
touch proto/buf.yaml
touch proto/buf.gen.yaml

# 2. Define your service in proto/api/v1/*_service.proto
#    Follow patterns from go-project-proto

# 3. Generate Go code
cd proto && buf generate

# 4. Now you can create server layer files that import generated code
```

**Without proto generated code, server files will fail to compile!**

## Directory Structure

```
server/
├── server.go              # Echo + cmux + service registration (THIS FILE)
├── auth/                  # Authentication logic
│   ├── authenticator.go   # Token validation (JWT, PAT, Refresh)
│   ├── claims.go          # User claims struct
│   ├── context.go         # Context helpers
│   ├── extract.go         # Token extraction
│   └── token.go           # Token generation & validation
├── router/                # HTTP/gRPC routing
│   └── api/v1/            # Connect RPC + gRPC-Gateway handlers
│       ├── v1.go          # Service registration, gateway setup
│       ├── acl_config.go  # Public endpoints whitelist
│       ├── connect_interceptors.go  # Interceptors chain
│       ├── connect_handler.go       # Connect handler wrapper
│       ├── connect_services.go      # Connect service implementations
│       ├── header_carrier.go        # Protocol-agnostic header handling
│       ├── auth_service.go          # AuthService implementation
│       ├── user_service.go          # UserService implementation
│       └── ...
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      main.go                             │
│                  (cmd/server/main.go)                    │
│         Cobra CLI → Profile → server.Start()             │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    server/server.go                      │
│  ┌─────────────────────────────────────────────────────┐│
│  │ Echo Server + cmux + Service Registration           ││
│  │ - middleware.Recover, Logger, CORS                  ││
│  │ - cmux: HTTP/1.1 ↔ HTTP/2 multiplexing             ││
│  │ - Register Gateway & Connect handlers               ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ router/api/  │ │   server/    │ │   server/    │
    │ v1/          │ │   auth/      │ │   runner/    │
    │ - Services   │ │   - JWT      │ │   - Tasks    │
    │ - Gateways   │ │   - PAT      │ │   - S3       │
    └──────────────┘ └──────────────┘ └──────────────┘
```

## Complete server/server.go Example

```go
package server

import (
    "context"
    "fmt"
    "net"
    "net/http"
    "sync"
    "time"

    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"
    "github.com/soheilhy/cmux"
    "google.golang.org/grpc"

    v1pb "github.com/myapp/gen/api/v1"
    "github.com/myapp/internal/profile"
    "github.com/myapp/server/router/api/v1"
    "github.com/myapp/store"
)

type Server struct {
    Profile *profile.Profile
    Store   *store.Store
    Secret  string

    echoServer        *echo.Echo
    grpcServer        *grpc.Server
    apiV1Service      *v1.APIV1Service
    wg                sync.WaitGroup
}

func NewServer(ctx context.Context, prof *profile.Profile, store *store.Store) (*Server, error) {
    s := &Server{
        Profile: prof,
        Store:   store,
    }

    // Echo setup
    echoServer := echo.New()
    echoServer.Debug = prof.IsDev()
    echoServer.HideBanner = true
    echoServer.Use(middleware.Recover())
    echoServer.Use(middleware.Logger())
    echoServer.Use(middleware.CORS())
    s.echoServer = echoServer

    // Health check endpoint
    echoServer.GET("/healthz", func(c echo.Context) error {
        return c.String(http.StatusOK, "Service ready.")
    })

    // Get or create secret
    secret, err := s.getOrCreateSecret(ctx)
    if err != nil {
        return nil, fmt.Errorf("failed to get secret: %w", err)
    }
    s.Secret = secret

    // Create API v1 service (embedded Unimplemented*Server for gRPC compatibility)
    s.apiV1Service = v1.NewAPIV1Service(s.Secret, prof, store)

    // Create gRPC server and register all services
    s.grpcServer = grpc.NewServer()
    // Register services: Instance, Auth, User, Memo, Attachment, etc.
    v1pb.RegisterInstanceServiceServer(s.grpcServer, s.apiV1Service)
    v1pb.RegisterAuthServiceServer(s.grpcServer, s.apiV1Service)
    v1pb.RegisterUserServiceServer(s.grpcServer, s.apiV1Service)
    // ... register other services

    return s, nil
}

func (s *Server) getOrCreateSecret(ctx context.Context) (string, error) {
    setting, err := s.Store.GetInstanceBasicSetting(ctx)
    if err != nil {
        return "", err
    }
    if setting.SecretKey != "" {
        return setting.SecretKey, nil
    }
    secret := generateRandomSecret()
    setting.SecretKey = secret
    _, err = s.Store.UpsertInstanceSetting(ctx, &store.InstanceSetting{Key: store.InstanceSettingKeyBasic, Value: setting})
    return secret, err
}

func (s *Server) Start(ctx context.Context) error {
    address := fmt.Sprintf("%s:%d", s.Profile.Addr, s.Profile.Port)

    listener, err := net.Listen("tcp", address)
    if err != nil {
        return fmt.Errorf("failed to listen: %w", err)
    }

    // cmux: multiplex HTTP/1.1 and HTTP/2 on single port
    m := cmux.New(listener)
    httpListener := m.Match(cmux.HTTP1Fast())  // REST + Gateway + Connect
    grpcListener := m.Match(cmux.HTTP2())      // Native gRPC

    // Start gRPC server on HTTP/2 listener
    s.wg.Add(1)
    go func() {
        defer s.wg.Done()
        s.echoServer.Logger.Info("gRPC server starting on ", address)
        s.grpcServer.Serve(grpcListener)
    }()

    // Register REST/Gateway handlers (on Echo)
    if err := s.apiV1Service.RegisterGateway(ctx, s.echoServer); err != nil {
        return err
    }

    // Start Echo server on HTTP/1.1 listener
    s.echoServer.Listener = httpListener
    s.wg.Add(1)
    go func() {
        defer s.wg.Done()
        s.echoServer.Logger.Info("Echo server starting on ", address)
        s.echoServer.Start(address)
    }()

    // Start cmux router
    s.wg.Add(1)
    go func() {
        defer s.wg.Done()
        m.Serve()
    }()

    s.echoServer.Logger.Info("Server started successfully (HTTP/1.1 + HTTP/2)")
    return nil
}

func (s *Server) Shutdown(ctx context.Context) error {
    s.echoServer.Logger.Info("Shutting down server...")

    // Graceful stop gRPC server first
    if s.grpcServer != nil {
        s.grpcServer.GracefulStop()
    }

    // Shutdown Echo server
    ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()
    s.echoServer.Shutdown(ctx)

    s.Store.Close()
    s.wg.Wait()
    return nil
}

func generateRandomSecret() string {
    return "your-secret-key-here"
}
```

## Dual Protocol Support (HTTP/1.1 + HTTP/2)

The server supports **three protocols simultaneously** on a single port using cmux:

```
                         ┌─────────────────────────┐
                         │   Single Listener       │
                         │   (TCP port 8081)       │
                         └───────────┬─────────────┘
                                     │
                         ┌───────────▼─────────────┐
                         │       cmux.New()        │
                         │   Connection Multiplexer│
                         └───────────┬─────────────┘
                                     │
           ┌─────────────────────────┼─────────────────────────┐
           │                         │                         │
┌─────────▼─────────┐     ┌─────────▼─────────┐     ┌─────────▼─────────┐
│ cmux.HTTP1Fast()  │     │      Other        │     │  cmux.HTTP2()     │
│  (HTTP/1.1)       │     │   (matchers)      │     │   (HTTP/2)        │
└─────────┬─────────┘     └───────────────────┘     └─────────┬─────────┘
          │                                                 │
┌─────────▼─────────┐                             ┌─────────▼─────────┐
│    Echo Server    │                             │   gRPC Server     │
│                   │                             │                   │
│ /api/v1/*         │                             │ All proto services│
│   └> gRPC-Gateway │                             │ registered        │
│ /memos.api.v1.*   │                             │                   │
│   └> Connect      │                             │                   │
└───────────────────┘                             └───────────────────┘

Protocols:
- REST API:        http://localhost:8081/api/v1/users
- Connect RPC:     http://localhost:8081/myapp.api.v1.*
- Native gRPC:     grpc://localhost:8081 (HTTP/2)
```

### Service Registration (Three Protocols)

```go
// 1. Native gRPC (HTTP/2)
v1pb.RegisterUserServiceServer(s.grpcServer, s.apiV1Service)

// 2. gRPC-Gateway (REST over HTTP/1.1)
v1pb.RegisterUserServiceHandlerServer(ctx, gwMux, s)

// 3. Connect RPC (browser clients over HTTP/1.1)
connectHandler.RegisterConnectHandlers(connectMux,
    connect.WithInterceptors(NewAuthInterceptor(s.Store, s.Secret)),
)
```

## RegisterGateway Implementation (router/api/v1/v1.go)

The `RegisterGateway` method is the core of API registration. It handles both gRPC-Gateway and Connect protocols.

```go
package v1

import (
    "context"
    "net/http"

    "connectrpc.com/connect"
    "github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"

    v1pb "github.com/myapp/gen/api/v1"
    "github.com/myapp/internal/profile"
    "github.com/myapp/server/auth"
    "github.com/myapp/store"
)

type APIV1Service struct {
    // Embed Unimplemented*Server for all services (gRPC compatibility)
    v1pb.UnimplementedInstanceServiceServer
    v1pb.UnimplementedAuthServiceServer
    v1pb.UnimplementedUserServiceServer
    v1pb.UnimplementedMemoServiceServer
    v1pb.UnimplementedAttachmentServiceServer
    // ... other services

    Secret  string
    Profile *profile.Profile
    Store   *store.Store
}

func NewAPIV1Service(secret string, profile *profile.Profile, store *store.Store) *APIV1Service {
    return &APIV1Service{
        Secret:  secret,
        Profile: profile,
        Store:   store,
    }
}

// RegisterGateway registers the gRPC-Gateway and Connect handlers with the given Echo instance.
func (s *APIV1Service) RegisterGateway(ctx context.Context, echoServer *echo.Echo) error {
    // =====================================================
    // STEP 1: Gateway Auth Middleware
    // =====================================================
    // This middleware runs AFTER routing, has access to RPC method name.
    // Uses the same PublicMethods config as Connect AuthInterceptor.
    authenticator := auth.NewAuthenticator(s.Store, s.Secret)
    gatewayAuthMiddleware := func(next runtime.HandlerFunc) runtime.HandlerFunc {
        return func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
            ctx := r.Context()

            // Get the RPC method name from context (set by grpc-gateway after routing)
            rpcMethod, ok := runtime.RPCMethod(ctx)

            // Extract credentials from HTTP headers
            authHeader := r.Header.Get("Authorization")

            // Execute authentication
            result := authenticator.Authenticate(ctx, authHeader)

            // Enforce authentication for non-public methods
            // If rpcMethod cannot be determined, allow through - service layer will handle visibility
            if result == nil && ok && !IsPublicMethod(rpcMethod) {
                http.Error(w, `{"code": 16, "message": "authentication required"}`, http.StatusUnauthorized)
                return
            }

            // Set context based on auth result (may be nil for public endpoints)
            if result != nil {
                if result.Claims != nil {
                    // Access Token V2 - stateless, use claims
                    ctx = auth.SetUserClaimsInContext(ctx, result.Claims)
                    ctx = context.WithValue(ctx, auth.UserIDContextKey, result.Claims.UserID)
                } else if result.User != nil {
                    // PAT - have full user info
                    ctx = auth.SetUserInContext(ctx, result.User, result.AccessToken)
                }
                r = r.WithContext(ctx)
            }

            next(w, r, pathParams)
        }
    }

    // =====================================================
    // STEP 2: gRPC-Gateway Registration
    // =====================================================
    // Create gRPC-Gateway mux with auth middleware
    gwMux := runtime.NewServeMux(
        runtime.WithMiddlewares(gatewayAuthMiddleware),
    )

    // Register all service handlers
    if err := v1pb.RegisterAuthServiceHandlerServer(ctx, gwMux, s); err != nil {
        return err
    }
    if err := v1pb.RegisterUserServiceHandlerServer(ctx, gwMux, s); err != nil {
        return err
    }
    // Register other services: Instance, Memo, Attachment, etc.
    // if err := v1pb.RegisterInstanceServiceHandlerServer(ctx, gwMux, s); err != nil { return err }
    // if err := v1pb.RegisterMemoServiceHandlerServer(ctx, gwMux, s); err != nil { return err }
    // ... other services

    // Create gateway route group with CORS
    gwGroup := echoServer.Group("")
    gwGroup.Use(middleware.CORS())
    handler := echo.WrapHandler(gwMux)

    // Register gateway routes
    gwGroup.Any("/api/v1/*", handler)
    gwGroup.Any("/file/*", handler)

    // =====================================================
    // STEP 3: Connect Handlers Registration
    // =====================================================
    // Connect handlers for browser clients (replaces grpc-web)
    logStacktraces := s.Profile.Demo
    connectInterceptors := connect.WithInterceptors(
        NewMetadataInterceptor(),      // Convert HTTP headers to gRPC metadata first
        NewLoggingInterceptor(logStacktraces),
        NewRecoveryInterceptor(logStacktraces),
        NewAuthInterceptor(s.Store, s.Secret),
    )

    connectMux := http.NewServeMux()
    connectHandler := NewConnectServiceHandler(s)
    connectHandler.RegisterConnectHandlers(connectMux, connectInterceptors)

    // Configure detailed CORS for browser access
    corsHandler := middleware.CORSWithConfig(middleware.CORSConfig{
        AllowOriginFunc: func(_ string) (bool, error) {
            return true, nil // Allow all origins in development
        },
        AllowMethods:     []string{http.MethodGet, http.MethodPost, http.MethodOptions},
        AllowHeaders:     []string{"*"},
        AllowCredentials: true,
    })

    // Create Connect route group with CORS
    connectGroup := echoServer.Group("", corsHandler)
    connectGroup.Any("/myapp.api.v1.*", echo.WrapHandler(connectMux))

    return nil
}
```

## Public Endpoints Configuration (router/api/v1/acl_config.go)

```go
package v1

// PublicMethods defines API endpoints that don't require authentication.
// This is the SINGLE SOURCE OF TRUTH for public endpoints.
// Both Connect interceptor and gRPC-Gateway interceptor use this map.
//
// Format: Full gRPC procedure path as returned by req.Spec().Procedure (Connect)
// or info.FullMethod (gRPC interceptor).
var PublicMethods = map[string]struct{}{
    // Auth Service - login/token endpoints must be accessible without auth
    "/myapp.api.v1.AuthService/SignIn":       {},
    "/myapp.api.v1.AuthService/RefreshToken": {}, // Token refresh uses cookie

    // Instance Service - needed before login to show instance info
    "/myapp.api.v1.InstanceService/GetInstanceProfile": {},
    "/myapp.api.v1.InstanceService/GetInstanceSetting": {},

    // User Service - public user profiles and stats
    "/myapp.api.v1.UserService/CreateUser": {}, // Allow first user registration
    "/myapp.api.v1.UserService/GetUser":    {},
}

// IsPublicMethod checks if a procedure path is public (no authentication required).
func IsPublicMethod(procedure string) bool {
    _, ok := PublicMethods[procedure]
    return ok
}
```

## Connect Interceptors (router/api/v1/connect_interceptors.go)

### MetadataInterceptor - Convert HTTP headers to gRPC metadata

```go
package v1

import (
    "context"

    "connectrpc.com/connect"
    "google.golang.org/grpc/metadata"
)

// MetadataInterceptor converts Connect HTTP headers to gRPC metadata.
//
// This ensures service methods can use metadata.FromIncomingContext() to access
// headers like User-Agent, X-Forwarded-For, etc.
type MetadataInterceptor struct{}

func NewMetadataInterceptor() *MetadataInterceptor {
    return &MetadataInterceptor{}
}

func (*MetadataInterceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
    return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
        // Convert HTTP headers to gRPC metadata
        header := req.Header()
        md := metadata.MD{}

        // Copy important headers for client info extraction
        if ua := header.Get("User-Agent"); ua != "" {
            md.Set("user-agent", ua)
        }
        if xff := header.Get("X-Forwarded-For"); xff != "" {
            md.Set("x-forwarded-for", xff)
        }
        if xri := header.Get("X-Real-Ip"); xri != "" {
            md.Set("x-real-ip", xri)
        }
        // Forward Cookie header for authentication
        if cookie := header.Get("Cookie"); cookie != "" {
            md.Set("cookie", cookie)
        }

        // Set metadata in context
        ctx = metadata.NewIncomingContext(ctx, md)

        // Execute the request
        resp, err := next(ctx, req)

        // Prevent browser caching of API responses
        if resp != nil && resp.Header() != nil {
            resp.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
            resp.Header().Set("Pragma", "no-cache")
            resp.Header().Set("Expires", "0")
        }

        return resp, err
    }
}

func (*MetadataInterceptor) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
    return next
}

func (*MetadataInterceptor) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
    return next
}
```

### LoggingInterceptor - Request logging with appropriate log levels

```go
package v1

import (
    "context"
    "fmt"
    "log/slog"

    "connectrpc.com/connect"
    pkgerrors "github.com/pkg/errors"
)

// LoggingInterceptor logs Connect RPC requests with appropriate log levels.
type LoggingInterceptor struct {
    logStacktrace bool
}

func NewLoggingInterceptor(logStacktrace bool) *LoggingInterceptor {
    return &LoggingInterceptor{logStacktrace: logStacktrace}
}

func (in *LoggingInterceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
    return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
        resp, err := next(ctx, req)
        in.log(req.Spec().Procedure, err)
        return resp, err
    }
}

func (in *LoggingInterceptor) log(procedure string, err error) {
    level, msg := in.classifyError(err)
    attrs := []slog.Attr{slog.String("method", procedure)}
    if err != nil {
        attrs = append(attrs, slog.String("error", err.Error()))
        if in.logStacktrace {
            attrs = append(attrs, slog.String("stacktrace", fmt.Sprintf("%+v", err)))
        }
    }
    slog.LogAttrs(context.Background(), level, msg, attrs...)
}

func (in *LoggingInterceptor) classifyError(err error) (slog.Level, string) {
    if err == nil {
        return slog.LevelInfo, "OK"
    }

    var connectErr *connect.Error
    if !pkgerrors.As(err, &connectErr) {
        return slog.LevelError, "unknown error"
    }

    // Client errors (expected, log at INFO)
    switch connectErr.Code() {
    case connect.CodeCanceled,
        connect.CodeInvalidArgument,
        connect.CodeNotFound,
        connect.CodeAlreadyExists,
        connect.CodePermissionDenied,
        connect.CodeUnauthenticated,
        connect.CodeResourceExhausted,
        connect.CodeFailedPrecondition,
        connect.CodeAborted,
        connect.CodeOutOfRange:
        return slog.LevelInfo, "client error"
    default:
        return slog.LevelError, "server error"
    }
}
```

### RecoveryInterceptor - Panic recovery

```go
package v1

import (
    "context"
    "fmt"
    "runtime/debug"

    "connectrpc.com/connect"
    pkgerrors "github.com/pkg/errors"
)

// RecoveryInterceptor recovers from panics in Connect handlers.
type RecoveryInterceptor struct {
    logStacktrace bool
}

func NewRecoveryInterceptor(logStacktrace bool) *RecoveryInterceptor {
    return &RecoveryInterceptor{logStacktrace: logStacktrace}
}

func (in *RecoveryInterceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
    return func(ctx context.Context, req connect.AnyRequest) (resp connect.AnyResponse, err error) {
        defer func() {
            if r := recover(); r != nil {
                in.logPanic(req.Spec().Procedure, r)
                err = connect.NewError(connect.CodeInternal, pkgerrors.New("internal server error"))
            }
        }()
        return next(ctx, req)
    }
}

func (in *RecoveryInterceptor) logPanic(procedure string, panicValue any) {
    attrs := []slog.Attr{
        slog.String("method", procedure),
        slog.Any("panic", panicValue),
    }
    if in.logStacktrace {
        attrs = append(attrs, slog.String("stacktrace", string(debug.Stack())))
    }
    slog.LogAttrs(context.Background(), slog.LevelError, "panic recovered in Connect handler", attrs...)
}
```

### AuthInterceptor - Authentication for Connect handlers

```go
package v1

import (
    "context"
    "errors"

    "connectrpc.com/connect"

    "github.com/myapp/server/auth"
    "github.com/myapp/store"
)

// AuthInterceptor handles authentication for Connect handlers.
type AuthInterceptor struct {
    authenticator *auth.Authenticator
}

func NewAuthInterceptor(store *store.Store, secret string) *AuthInterceptor {
    return &AuthInterceptor{
        authenticator: auth.NewAuthenticator(store, secret),
    }
}

func (in *AuthInterceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
    return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
        header := req.Header()
        authHeader := header.Get("Authorization")

        result := in.authenticator.Authenticate(ctx, authHeader)

        // Enforce authentication for non-public methods
        if result == nil && !IsPublicMethod(req.Spec().Procedure) {
            return nil, connect.NewError(connect.CodeUnauthenticated, errors.New("authentication required"))
        }

        // Set context based on auth result
        if result != nil {
            if result.Claims != nil {
                ctx = auth.SetUserClaimsInContext(ctx, result.Claims)
                ctx = context.WithValue(ctx, auth.UserIDContextKey, result.Claims.UserID)
            } else if result.User != nil {
                ctx = auth.SetUserInContext(ctx, result.User, result.AccessToken)
            }
        }

        return next(ctx, req)
    }
}
```

## Connect Handler Wrapper (router/api/v1/connect_handler.go)

```go
package v1

import (
    "net/http"

    "connectrpc.com/connect"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"

    "github.com/myapp/proto/gen/api/v1/apiv1connect"
)

// ConnectServiceHandler wraps APIV1Service to implement Connect handler interfaces.
type ConnectServiceHandler struct {
    *APIV1Service
}

func NewConnectServiceHandler(svc *APIV1Service) *ConnectServiceHandler {
    return &ConnectServiceHandler{APIV1Service: svc}
}

// RegisterConnectHandlers registers all Connect service handlers on the given mux.
func (s *ConnectServiceHandler) RegisterConnectHandlers(mux *http.ServeMux, opts ...connect.HandlerOption) {
    handlers := []struct {
        path    string
        handler http.Handler
    }{
        wrap(apiv1connect.NewAuthServiceHandler(s, opts...)),
        wrap(apiv1connect.NewUserServiceHandler(s, opts...)),
        // Add more services as needed
    }

    for _, h := range handlers {
        mux.Handle(h.path, h.handler)
    }
}

func wrap(path string, handler http.Handler) struct {
    path    string
    handler http.Handler
} {
    return struct {
        path    string
        handler http.Handler
    }{path, handler}
}

// convertGRPCError converts gRPC status errors to Connect errors.
func convertGRPCError(err error) error {
    if err == nil {
        return nil
    }
    if st, ok := status.FromError(err); ok {
        return connect.NewError(grpcCodeToConnectCode(st.Code()), err)
    }
    return connect.NewError(connect.CodeInternal, err)
}

func grpcCodeToConnectCode(code codes.Code) connect.Code {
    return connect.Code(code)
}
```

## Protocol-Agnostic Header Handling (router/api/v1/header_carrier.go)

```go
package v1

import (
    "context"

    "connectrpc.com/connect"
    "google.golang.org/grpc"
    "google.golang.org/grpc/metadata"
)

// headerCarrierKey is the context key for storing headers to be set in the response.
type headerCarrierKey struct{}

// HeaderCarrier stores headers that need to be set in the response.
type HeaderCarrier struct {
    headers map[string]string
}

func newHeaderCarrier() *HeaderCarrier {
    return &HeaderCarrier{
        headers: make(map[string]string),
    }
}

func (h *HeaderCarrier) Set(key, value string) {
    h.headers[key] = value
}

func (h *HeaderCarrier) Get(key string) string {
    return h.headers[key]
}

func (h *HeaderCarrier) All() map[string]string {
    return h.headers
}

func WithHeaderCarrier(ctx context.Context) context.Context {
    return context.WithValue(ctx, headerCarrierKey{}, newHeaderCarrier())
}

func GetHeaderCarrier(ctx context.Context) *HeaderCarrier {
    if carrier, ok := ctx.Value(headerCarrierKey{}).(*HeaderCarrier); ok {
        return carrier
    }
    return nil
}

func SetResponseHeader(ctx context.Context, key, value string) error {
    if carrier := GetHeaderCarrier(ctx); carrier != nil {
        carrier.Set(key, value)
        return nil
    }
    return grpc.SetHeader(ctx, metadata.New(map[string]string{key: value}))
}

func connectWithHeaderCarrier[T any](ctx context.Context, fn func(context.Context) (*T, error)) (*connect.Response[T], error) {
    ctx = WithHeaderCarrier(ctx)
    resp, err := fn(ctx)
    if err != nil {
        return nil, convertGRPCError(err)
    }
    connectResp := connect.NewResponse(resp)
    if carrier := GetHeaderCarrier(ctx); carrier != nil {
        for key, value := range carrier.All() {
            connectResp.Header().Set(key, value)
        }
    }
    return connectResp, nil
}
```

## Connect Services (router/api/v1/connect_services.go)

```go
package v1

import (
    "context"

    "connectrpc.com/connect"

    v1pb "github.com/myapp/gen/api/v1"
)

// AuthService Connect handlers - use connectWithHeaderCarrier for headers/cookies

func (s *ConnectServiceHandler) SignIn(ctx context.Context, req *connect.Request[v1pb.SignInRequest]) (*connect.Response[v1pb.SignInResponse], error) {
    return connectWithHeaderCarrier(ctx, func(ctx context.Context) (*v1pb.SignInResponse, error) {
        return s.APIV1Service.SignIn(ctx, req.Msg)
    })
}

// UserService Connect handlers - use convertGRPCError for error conversion

func (s *ConnectServiceHandler) GetUser(ctx context.Context, req *connect.Request[v1pb.GetUserRequest]) (*connect.Response[v1pb.User], error) {
    resp, err := s.APIV1Service.GetUser(ctx, req.Msg)
    if err != nil {
        return nil, convertGRPCError(err)
    }
    return connect.NewResponse(resp), nil
}

// Pattern: Delegate to APIV1Service, convert errors
func (s *ConnectServiceHandler) ListUsers(ctx context.Context, req *connect.Request[v1pb.ListUsersRequest]) (*connect.Response[v1pb.ListUsersResponse], error) {
    resp, err := s.APIV1Service.ListUsers(ctx, req.Msg)
    if err != nil {
        return nil, convertGRPCError(err)
    }
    return connect.NewResponse(resp), nil
}

// Add more service methods following the same pattern...
```

## Authentication Module (server/auth/)

### claims.go - User Claims

```go
package auth

type UserClaims struct {
    UserID   int32
    Username string
    Role     string
    Status   string
}

type ContextKey int

const (
    UserIDContextKey ContextKey = iota
    AccessTokenContextKey
    UserClaimsContextKey
    RefreshTokenIDContextKey
)

func GetUserID(ctx context.Context) int32 {
    if v, ok := ctx.Value(UserIDContextKey).(int32); ok {
        return v
    }
    return 0
}

func GetUserClaims(ctx context.Context) *UserClaims {
    if v, ok := ctx.Value(UserClaimsContextKey).(*UserClaims); ok {
        return v
    }
    return nil
}

func SetUserClaimsInContext(ctx context.Context, claims *UserClaims) context.Context {
    return context.WithValue(ctx, UserClaimsContextKey, claims)
}

func SetUserInContext(ctx context.Context, user *store.User, accessToken string) context.Context {
    ctx = context.WithValue(ctx, UserIDContextKey, user.ID)
    if accessToken != "" {
        ctx = context.WithValue(ctx, AccessTokenContextKey, accessToken)
    }
    return ctx
}
```

### token.go - JWT Token

```go
package auth

import (
    "crypto/rand"
    "encoding/base64"
    "time"

    "github.com/golang-jwt/jwt/v5"
)

const AccessTokenDuration = 15 * time.Minute

type JWTClaims struct {
    jwt.RegisteredClaims
    UserID   int32
    Username string
    Role     string
}

func GenerateAccessToken(userID int32, username, role, secret string) (string, error) {
    now := time.Now()
    claims := JWTClaims{
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(now.Add(AccessTokenDuration)),
            IssuedAt:  jwt.NewNumericDate(now),
            NotBefore: jwt.NewNumericDate(now),
            Issuer:    "myapp",
        },
        UserID:   userID,
        Username: username,
        Role:     role,
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}

func ValidateAccessToken(tokenString, secret string) (*JWTClaims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return []byte(secret), nil
    })

    if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
        return claims, nil
    }
    return nil, err
}

func GenerateRefreshToken() (string, error) {
    b := make([]byte, 32)
    _, err := rand.Read(b)
    if err != nil {
        return "", err
    }
    return base64.StdEncoding.EncodeToString(b), nil
}
```

### extract.go - Token Extraction

```go
package auth

import (
    "strings"
)

const BearerPrefix = "Bearer "

func ExtractBearerToken(authHeader string) string {
    if strings.HasPrefix(authHeader, BearerPrefix) {
        return strings.TrimPrefix(authHeader, BearerPrefix)
    }
    return ""
}
```

### authenticator.go - Main Authenticator

```go
package auth

import (
    "context"
    "strings"
    "time"

    "github.com/myapp/store"
)

const PersonalAccessTokenPrefix = "pat_"

type AuthResult struct {
    User       *store.User
    Claims     *UserClaims
    AccessToken string
}

type Authenticator struct {
    Store  *store.Store
    Secret string
}

func NewAuthenticator(store *store.Store, secret string) *Authenticator {
    return &Authenticator{Store: store, Secret: secret}
}

func (a *Authenticator) Authenticate(ctx context.Context, authHeader string) *AuthResult {
    token := ExtractBearerToken(authHeader)
    if token == "" {
        return nil
    }

    // Try Access Token V2 (stateless JWT)
    if !strings.HasPrefix(token, PersonalAccessTokenPrefix) {
        claims, err := a.AuthenticateByAccessTokenV2(token)
        if err == nil && claims != nil {
            return &AuthResult{
                Claims:     claims,
                AccessToken: token,
            }
        }
    }

    // Try PAT (stateful, database validated)
    if strings.HasPrefix(token, PersonalAccessTokenPrefix) {
        user, pat, err := a.AuthenticateByPAT(ctx, token)
        if err == nil && user != nil {
            go func() {
                ctx := context.Background()
                if err := a.store.UpdatePATLastUsed(ctx, user.ID, pat.TokenID, time.Now()); err != nil {
                    // Log error
                }
            }()
            return &AuthResult{User: user, AccessToken: token}
        }
    }

    return nil
}

func (a *Authenticator) AuthenticateByAccessTokenV2(token string) (*UserClaims, error) {
    claims, err := ValidateAccessToken(token, a.Secret)
    if err != nil {
        return nil, err
    }
    return &UserClaims{
        UserID:   claims.UserID,
        Username: claims.Username,
        Role:     claims.Role,
    }, nil
}

func (a *Authenticator) AuthenticateByPAT(ctx context.Context, token string) (*store.User, *store.PAT, error) {
    // Implementation depends on your PAT storage
    return nil, nil, nil
}
```

## Best Practices

### 1. Error Handling

```go
// Use connect.NewError with appropriate code
return nil, connect.NewError(connect.CodeNotFound, "resource not found")

// Wrap errors for context
return nil, connect.NewError(connect.CodeInternal, errors.Wrap(err, "failed to create user"))
```

### 2. Security

- Validate all inputs
- Use bcrypt/argon2 for password hashing
- Set appropriate token expiry (15min for access, 7 days for refresh)
- Log security events
- Use HTTPS in production

### 3. Performance

- Use database connection pools
- Cache frequently accessed data
- Use goroutines for async operations
- Limit request body sizes

## Key Patterns Summary

| Pattern | Location | Purpose |
|---------|----------|---------|
| cmux multiplexing | `server.go` | HTTP/1.1 + HTTP/2 on single port |
| Dual protocol | `v1.go` | Connect + gRPC-Gateway registration |
| Gateway auth | `v1.go:gatewayAuthMiddleware` | HTTP auth for REST API |
| Connect interceptors | `connect_interceptors.go` | Chain: Metadata → Logging → Recovery → Auth |
| Public methods | `acl_config.go` | Public endpoint whitelist |
| Header carrier | `header_carrier.go` | Protocol-agnostic headers |

## Related Skills

- [go-project-main](../go-project-main/) - CLI and server startup
- [go-project-proto](../go-project-proto/) - Protocol buffer definitions
- [go-project-store](../go-project-store/) - Database layer
- [go-project-conventions](../go-project-conventions/) - Code conventions
