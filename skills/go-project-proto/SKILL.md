---
name: go-project-proto
description: Protocol buffer configuration for Connect RPC + gRPC-Gateway using buf, including plugins, imports, annotations, and code generation
---

# Protocol Buffer Configuration (buf)

## ⚠️ CRITICAL: Proto Files Must Be Created First

**Before creating any server code, you MUST create proto definitions!**

```bash
# 1. Create proto directory
mkdir -p proto/api/v1

# 2. Create buf configuration files
touch proto/buf.yaml
touch proto/buf.gen.yaml

# 3. Create service definition
touch proto/api/v1/auth_service.proto

# 4. Generate Go code
cd proto && buf generate
```

**Without proto files, server implementations cannot import generated types and will fail to compile!**

## Directory Structure

```
proto/
├── buf.gen.yaml                    # Code generation configuration
├── buf.yaml                        # Lint and breaking change rules
├── buf.lock                        # Dependency lock file (auto-generated)
├── api/v1/                         # API service definitions
│   ├── auth_service.proto
│   ├── user_service.proto
│   ├── memo_service.proto
│   └── common.proto                # Shared enums
└── gen/                            # Generated code (auto-generated)
    ├── api/v1/
    │   ├── *_pb.go                # Protobuf messages
    │   ├── *_connect.go           # Connect RPC handlers
    │   ├── *_grpc.go              # gRPC stubs
    │   └── openapi.yaml           # OpenAPI spec
```

## buf.gen.yaml - Code Generation

```yaml
version: v2
managed:
  enabled: true
  disable:
    - file_option: go_package
      module: buf.build/googleapis/googleapis
  override:
    - file_option: go_package_prefix
      value: github.com/usememos/memos/proto/gen

plugins:
  - remote: buf.build/protocolbuffers/go
    out: gen
    opt: paths=source_relative

  - remote: buf.build/grpc/go
    out: gen
    opt: paths=source_relative

  - remote: buf.build/connectrpc/go
    out: gen
    opt: paths=source_relative

  - remote: buf.build/grpc-ecosystem/gateway
    out: gen
    opt: paths=source_relative

  - remote: buf.build/community/google-gnostic-openapi
    out: gen
    opt: enum_type=string

  - remote: buf.build/bufbuild/es
    out: ../web/src/types/proto
    opt: target=ts
    include_imports: true
```

## buf.yaml - Lint and Breaking Changes

```yaml
version: v2
deps:
  - buf.build/googleapis/googleapis

lint:
  use:
    - BASIC
  except:
    - ENUM_VALUE_PREFIX
    - FIELD_NOT_REQUIRED
    - PACKAGE_DIRECTORY_MATCH
    - PACKAGE_NO_IMPORT_CYCLE
    - PACKAGE_VERSION_SUFFIX
  disallow_comment_ignores: true

breaking:
  use:
    - FILE
  except:
    - EXTENSION_NO_DELETE
    - FIELD_SAME_DEFAULT
```

## Service Definition Pattern

```protobuf
syntax = "proto3";

package memos.api.v1;

import "google/api/annotations.proto";
import "google/api/client.proto";
import "google/api/field_behavior.proto";
import "google/api/resource.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

option go_package = "gen/api/v1";

service MemoService {
  rpc CreateMemo(CreateMemoRequest) returns (Memo) {
    option (google.api.http) = {
      post: "/api/v1/memos"
      body: "memo"
    };
    option (google.api.method_signature) = "memo";
  }

  rpc ListMemos(ListMemosRequest) returns (ListMemosResponse) {
    option (google.api.http) = {get: "/api/v1/memos"};
    option (google.api.method_signature) = "";
  }

  rpc GetMemo(GetMemoRequest) returns (Memo) {
    option (google.api.http) = {get: "/api/v1/{name=memos/*}"};
    option (google.api.method_signature) = "name";
  }

  rpc UpdateMemo(UpdateMemoRequest) returns (Memo) {
    option (google.api.http) = {
      patch: "/api/v1/{memo.name=memos/*}"
      body: "memo"
    };
    option (google.api.method_signature) = "memo,update_mask";
  }

  rpc DeleteMemo(DeleteMemoRequest) returns (google.protobuf.Empty) {
    option (google.api.http) = {delete: "/api/v1/{name=memos/*}"};
    option (google.api.method_signature) = "name";
  }
}
```

## Resource Definition Pattern

```protobuf
message Memo {
  option (google.api.resource) = {
    type: "memos.api.v1/Memo"
    pattern: "memos/{memo}"
    name_field: "name"
    singular: "memo"
    plural: "memos"
  };

  string name = 1 [(google.api.field_behavior) = IDENTIFIER];

  State state = 2 [(google.api.field_behavior) = REQUIRED];

  string creator = 3 [
    (google.api.field_behavior) = OUTPUT_ONLY,
    (google.api.resource_reference) = {type: "memos.api.v1/User"}
  ];

  google.protobuf.Timestamp create_time = 4 [(google.api.field_behavior) = OUTPUT_ONLY];

  string content = 7 [(google.api.field_behavior) = REQUIRED];
}

enum State {
  STATE_UNSPECIFIED = 0;
  NORMAL = 1;
  ARCHIVED = 2;
}
```

## Request/Response Messages

```protobuf
message ListMemosRequest {
  int32 page_size = 1 [(google.api.field_behavior) = OPTIONAL];
  string page_token = 2 [(google.api.field_behavior) = OPTIONAL];
  string order_by = 4 [(google.api.field_behavior) = OPTIONAL];
  string filter = 5 [(google.api.field_behavior) = OPTIONAL];
}

message ListMemosResponse {
  repeated Memo memos = 1;
  string next_page_token = 2;
}
```

## Field Behavior Annotations

| Annotation | Usage |
|------------|-------|
| `REQUIRED` | Field is required |
| `OPTIONAL` | Field is optional |
| `OUTPUT_ONLY` | Field is server-generated |
| `IDENTIFIER` | Field is the resource identifier |

## Common Types

```protobuf
// common.proto
syntax = "proto3";
package memos.api.v1;
option go_package = "gen/api/v1";

enum State {
  STATE_UNSPECIFIED = 0;
  NORMAL = 1;
  ARCHIVED = 2;
}

message PageToken {
  int32 limit = 1;
  int32 offset = 2;
}
```

## Commands

```bash
# Install dependencies
cd proto && buf dep update

# Generate code
cd proto && buf generate

# Lint proto files
cd proto && buf lint

# Check breaking changes
cd proto && buf breaking --against .git#main
```

## Generated Output

```
gen/
└── api/v1/
    ├── auth_service.pb.go
    ├── auth_service.connect.go
    ├── auth_service_grpc.go
    ├── memo_service.pb.go
    ├── memo_service.connect.go
    └── openapi.yaml
```

**Import path:**
```go
import v1pb "github.com/usememos/memos/gen/api/v1"
```

## Best Practices

1. **One service per file**: `*_service.proto`
2. **Shared types**: Use `common.proto` for enums
3. **Resource patterns**: Use `google.api.resource` for REST resources
4. **Field behavior**: Always annotate REQUIRED/OUTPUT_ONLY/OPTIONAL
5. **Method signature**: Document with `google.api.method_signature`
6. **RESTful HTTP paths**: HTTP paths in proto annotations must comply with RESTful API conventions, using appropriate HTTP methods and resource-based URLs

## Related Skills

- [go-project-server](../go-project-server/) - Server implementation with dual protocol
- [go-project-store](../go-project-store/) - Database models
- [go-project-conventions](../go-project-conventions/) - Code conventions
