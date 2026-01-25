---
name: go-project-store
description: Store layer patterns including Driver interface, Store wrapper with caching, migration system, and model definition patterns
---

# Store Layer

## Prerequisites

**IMPORTANT**: Store layer interfaces should be defined BEFORE creating server services that depend on them. However, proto definitions must come first:

```bash
# 1. Create proto directory and definitions FIRST (see go-project-proto)
mkdir -p proto/api/v1
touch proto/buf.yaml
touch proto/buf.gen.yaml

# 2. Define services in proto/api/v1/*_service.proto
#    Store models map to proto messages

# 3. Generate code
cd proto && buf generate

# 4. Create store layer (store/driver.go defines interfaces)
#    Proto messages reference store models

# 5. Create server layer (uses both proto and store)
```

**Order matters**: Proto → Store → Server

## Directory Structure

```
store/
├── store.go              # Store wrapper (STRUCTURAL)
├── driver.go             # Driver interface (STRUCTURAL)
├── cache.go              # Cache implementation (STRUCTURAL)
├── migrator.go           # Migration system (STRUCTURAL)
├── model.go              # Base types (STRUCTURAL)
├── {model}.go            # Model definitions + Store methods (BUSINESS)
├── db/
│   ├── db.go             # Driver factory (STRUCTURAL)
│   ├── sqlite/           # SQLite CRUD (BUSINESS)
│   ├── mysql/            # MySQL CRUD (BUSINESS)
│   └── postgres/         # PostgreSQL CRUD (BUSINESS)
├── migration/            # SQL migrations (BUSINESS)
│   ├── sqlite/
│   │   ├── LATEST.sql    # Full schema
│   │   └── 0.22/
│   │       └── 00__add_table.sql
│   ├── mysql/
│   └── postgres/
└── seed/                 # Demo data (BUSINESS)
```

## Driver Interface (store/driver.go)

```go
type Driver interface {
    // Lifecycle
    GetDB() *sql.DB
    Close() error
    IsInitialized(ctx context.Context) (bool, error)

    // User model - CRUD pattern
    CreateUser(ctx context.Context, create *User) (*User, error)
    UpdateUser(ctx context.Context, update *UpdateUser) (*User, error)
    ListUsers(ctx context.Context, find *FindUser) ([]*User, error)
    DeleteUser(ctx context.Context, delete *DeleteUser) error

    // Memo model (same CRUD pattern)
    CreateMemo(ctx context.Context, create *Memo) (*Memo, error)
    UpdateMemo(ctx context.Context, update *UpdateMemo) error
    ListMemos(ctx context.Context, find *FindMemo) ([]*Memo, error)
    DeleteMemo(ctx context.Context, delete *DeleteMemo) error
}
```

## Store Wrapper (store/store.go)

```go
type Store struct {
    driver  Driver
    profile *profile.Profile

    cacheConfig          cache.Config
    instanceSettingCache *cache.Cache
    userCache            *cache.Cache
    userSettingCache     *cache.Cache
}

func New(driver Driver, profile *profile.Profile) *Store {
    cacheConfig := cache.Config{
        DefaultTTL:      10 * time.Minute,
        CleanupInterval: 5 * time.Minute,
        MaxItems:        1000,
    }
    return &Store{
        driver:               driver,
        profile:              profile,
        cacheConfig:          cacheConfig,
        instanceSettingCache: cache.New(cacheConfig),
        userCache:            cache.New(cacheConfig),
        userSettingCache:     cache.New(cacheConfig),
    }
}

func (s *Store) GetDriver() Driver { return s.driver }

func (s *Store) Close() error {
    s.instanceSettingCache.Close()
    s.userCache.Close()
    s.userSettingCache.Close()
    return s.driver.Close()
}
```

## Model Definition Pattern (store/user.go)

```go
type User struct {
    ID int32
    RowStatus
    CreatedTs int64
    UpdatedTs int64

    Username     string
    Role         Role
    Email        string
    Nickname     string
    PasswordHash string
    AvatarURL    string
    Description  string
}

type UpdateUser struct {
    ID int32
    UpdatedTs    *int64
    RowStatus    *RowStatus
    Username     *string
    Role         *Role
    Email        *string
    // ... other optional fields
}

type FindUser struct {
    ID        *int32
    RowStatus *RowStatus
    Username  *string
    Role      *Role
    Filters   []string  // CEL expressions
    Limit     *int
}

type DeleteUser struct { ID int32 }
```

## Store Methods with Caching (store/user.go)

```go
func (s *Store) CreateUser(ctx context.Context, create *User) (*User, error) {
    user, err := s.driver.CreateUser(ctx, create)
    if err != nil { return nil, err }
    s.userCache.Set(ctx, string(user.ID), user)
    return user, nil
}

func (s *Store) GetUser(ctx context.Context, find *FindUser) (*User, error) {
    if find.ID != nil {
        if cached, ok := s.userCache.Get(ctx, string(*find.ID)); ok {
            if user, ok := cached.(*User); ok { return user, nil }
        }
    }
    list, err := s.ListUsers(ctx, find)
    if err != nil { return nil, err }
    return list[0], nil
}

func (s *Store) DeleteUser(ctx context.Context, delete *DeleteUser) error {
    if err := s.driver.DeleteUser(ctx, delete); err != nil { return err }
    s.userCache.Delete(ctx, string(delete.ID))
    return nil
}
```

## Driver Factory (store/db/db.go)

```go
func NewDBDriver(profile *profile.Profile) (store.Driver, error) {
    switch profile.Driver {
    case "sqlite":  return sqlite.NewDB(profile)
    case "mysql":   return mysql.NewDB(profile)
    case "postgres": return postgres.NewDB(profile)
    default:        return nil, fmt.Errorf("unsupported driver: %s", profile.Driver)
    }
}
```

## Migration System

### Embed Directives

```go
//go:embed migration
var migrationFS embed.FS

//go:embed seed
var seedFS embed.FS
```

### Migration Flow

```go
func (s *Store) Migrate(ctx context.Context) error {
    // Step 1: preMigrate - Check if DB is initialized
    if err := s.preMigrate(ctx); err != nil {
        return errors.Wrap(err, "failed to pre-migrate")
    }

    // Step 2: Apply migrations based on mode
    switch s.profile.Mode {
    case modeProd:
        if err := s.migrateProd(ctx); err != nil {
            return err
        }
    case modeDemo:
        if err := s.seed(ctx); err != nil {
            return errors.Wrap(err, "failed to seed")
        }
    }
    return nil
}
```

### Pre-Migrate (Fresh Install)

```go
func (s *Store) preMigrate(ctx context.Context) error {
    initialized, err := s.driver.IsInitialized(ctx)
    if err != nil {
        return errors.Wrap(err, "failed to check if database is initialized")
    }

    if !initialized {
        // Fresh installation - apply full schema from LATEST.sql
        filePath := s.getMigrationBasePath() + "LATEST.sql"
        bytes, err := migrationFS.ReadFile(filePath)
        if err != nil {
            return errors.Wrapf(err, "failed to read latest schema file")
        }

        tx, err := s.driver.GetDB().Begin()
        if err != nil {
            return errors.Wrap(err, "failed to start transaction")
        }
        defer tx.Rollback()

        if err := s.execute(ctx, tx, string(bytes)); err != nil {
            return errors.Wrapf(err, "failed to execute latest schema")
        }

        return tx.Commit()
    }
    return nil
}
```

### Production Migration (Incremental)

```go
func (s *Store) migrateProd(ctx context.Context) error {
    currentVersion := s.GetCurrentSchemaVersion()

    pattern := fmt.Sprintf("%s*/*.sql", s.getMigrationBasePath())
    filePaths, _ := fs.Glob(migrationFS, pattern)

    sort.Strings(filePaths)

    tx, err := s.driver.GetDB().Begin()
    if err != nil {
        return errors.Wrap(err, "failed to start transaction")
    }
    defer tx.Rollback()

    for _, filePath := range filePaths {
        fileVersion := s.getSchemaVersionOfMigrateScript(filePath)
        if version.IsVersionGreaterThan(fileVersion, currentVersion) {
            bytes, _ := migrationFS.ReadFile(filePath)
            if err := s.execute(ctx, tx, string(bytes)); err != nil {
                return errors.Wrapf(err, "failed to execute: %s", filePath)
            }
        }
    }

    return tx.Commit()
}
```

## Migration Files

### LATEST.sql (Complete Schema)

```sql
-- store/migration/sqlite/LATEST.sql

CREATE TABLE system_setting (
    name TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT ''
);

CREATE TABLE user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_ts BIGINT NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_ts BIGINT NOT NULL DEFAULT (strftime('%s', 'now')),
    row_status TEXT NOT NULL DEFAULT 'NORMAL',
    username TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'USER',
    email TEXT NOT NULL DEFAULT '',
    nickname TEXT NOT NULL DEFAULT '',
    password_hash TEXT NOT NULL,
    avatar_url TEXT NOT NULL DEFAULT ''
);

CREATE TABLE memo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    creator_id INTEGER NOT NULL,
    created_ts BIGINT NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_ts BIGINT NOT NULL DEFAULT (strftime('%s', 'now')),
    row_status TEXT NOT NULL DEFAULT 'NORMAL',
    content TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_user_created_ts ON user(created_ts);
CREATE INDEX idx_memo_created_ts ON memo(created_ts);
CREATE INDEX idx_memo_creator_id ON memo(creator_id);
```

### Incremental Migration

```sql
-- store/migration/sqlite/0.22/00__add_memo_relation.sql
CREATE TABLE memo_relation (
    memo_id INTEGER NOT NULL,
    related_memo_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    UNIQUE(memo_id, related_memo_id, type)
);
```

## Quick Reference

| File | Type | Purpose |
|------|------|---------|
| `store.go` | Structural | Cache wrapper, lifecycle |
| `driver.go` | Structural | Interface for CRUD operations |
| `cache.go` | Structural | In-memory cache |
| `migrator.go` | Structural | Migration system |
| `{model}.go` | Business | Model + Store methods |
| `db/db.go` | Structural | Driver factory |
| `migration/driver/LATEST.sql` | Business | Complete schema |

## Key Patterns

| Pattern | Description |
|---------|-------------|
| **Caching** | Store wraps Driver, adds cache ops |
| **Dynamic Updates** | Update structs use pointers |
| **Timestamps** | Unix (`int64`), not `time.Time` |
| **RETURNING** | Get generated IDs |
| **Migration Flow** | preMigrate -> migrateProd -> seed |
| **Atomic Migrations** | Single transaction |

## Related Skills

- [go-project-main](../go-project-main/) - CLI and startup flow
- [go-project-server](../go-project-server/) - Server implementation
- [go-project-proto](../go-project-proto/) - Protocol buffer definitions
- [go-project-conventions](../go-project-conventions/) - Code conventions
