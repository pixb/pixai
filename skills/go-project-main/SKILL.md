---
name: go-project-main
description: CLI patterns with Cobra/Viper, profile configuration, and graceful shutdown with signal handling
---

# Main Entry Point

## ⚠️ CRITICAL: File Separation

**DO NOT put server code in main.go!**

`cmd/server/main.go` should ONLY contain:
- Cobra CLI setup
- Profile creation/validation
- Signal handling
- Call to `server.NewServer()` and `server.Start()`

All server logic belongs in `server/server.go` (see go-project-server).

## File Structure

```
cmd/server/
└── main.go              # ONLY CLI entry point, 50-100 lines max

server/
├── server.go            # Echo + cmux + service registration (200+ lines)
├── auth/                # Authentication logic
└── router/api/v1/       # Service implementations
```

**WRONG** (what you generated):
```go
// cmd/server/main.go
func main() {
    // ❌ Echo setup here
    // ❌ Routes here
    // ❌ Handlers here
    // ❌ All business logic
}
```

**CORRECT**:
```go
// cmd/server/main.go
func main() {
    // ✓ Cobra CLI
    // ✓ Profile validation
    // ✓ Create server.NewServer()
    // ✓ server.Start()
    // ✓ Signal handling
}
```

## CLI Structure with Cobra

```go
package main

import (
    "context"
    "os"
    "os/signal"
    "syscall"

    "github.com/spf13/cobra"
    "github.com/spf13/viper"

    "github.com/myapp/internal/profile"
    "github.com/myapp/server"
    "github.com/myapp/store/db"
)

var rootCmd = &cobra.Command{
    Use:   "server",
    Short: "Start API server",
    RunE: func(cmd *cobra.Command, args []string) error {
        prof := &profile.Profile{
            Mode:   viper.GetString("mode"),
            Addr:   viper.GetString("addr"),
            Port:   viper.GetInt("port"),
            Data:   viper.GetString("data"),
            Driver: viper.GetString("driver"),
            DSN:    viper.GetString("dsn"),
        }
        return run(cmd.Context(), prof)
    },
}

func init() {
    rootCmd.Flags().String("mode", "dev", "dev|prod")
    rootCmd.Flags().String("addr", "0.0.0.0", "bind address")
    rootCmd.Flags().Int("port", 8081, "HTTP port")
    rootCmd.Flags().String("data", "./data", "data directory")
    rootCmd.Flags().String("driver", "sqlite", "database driver")
    rootCmd.Flags().String("dsn", "", "database connection string")

    viper.BindPFlags(rootCmd.Flags())
    viper.SetEnvPrefix("myapp")
    viper.AutomaticEnv()
}

func run(ctx context.Context, prof *profile.Profile) error {
    if err := prof.Validate(); err != nil {
        return err
    }

    dbDriver, err := db.NewDBDriver(prof)
    if err != nil {
        return err
    }

    storeInstance := store.New(dbDriver, prof)
    if err := storeInstance.Migrate(ctx); err != nil {
        return err
    }

    // ALL server logic in server/server.go
    s, err := server.NewServer(ctx, prof, storeInstance)
    if err != nil {
        return err
    }

    if err := s.Start(ctx); err != nil {
        return err
    }

    // Signal handling
    c := make(chan os.Signal, 1)
    signal.Notify(c, os.Interrupt, syscall.SIGTERM)
    <-c

    return s.Shutdown(ctx)
}

func main() {
    if err := rootCmd.Execute(); err != nil {
        os.Exit(1)
    }
}
```

## Configuration with Viper

```go
func init() {
    viper.SetDefault("mode", "dev")
    viper.SetDefault("driver", "sqlite")
    viper.SetDefault("port", 8081)

    rootCmd.PersistentFlags().String("mode", "dev", "mode description")
    rootCmd.PersistentFlags().String("addr", "", "address")
    rootCmd.PersistentFlags().Int("port", 8081, "port")
    rootCmd.PersistentFlags().String("data", "", "data directory")
    rootCmd.PersistentFlags().String("driver", "sqlite", "database driver")
    rootCmd.PersistentFlags().String("dsn", "", "database source name")
    rootCmd.PersistentFlags().String("instance-url", "", "instance URL")

    viper.BindPFlag("mode", rootCmd.PersistentFlags().Lookup("mode"))
    viper.BindPFlag("addr", rootCmd.PersistentFlags().Lookup("addr"))
    // ... bind other flags

    viper.SetEnvPrefix("app")
    viper.AutomaticEnv()
}
```

## Profile Validation Pattern

```go
type Profile struct {
    Mode     string
    Addr     string
    Port     int
    UNIXSock string
    Data     string
    DSN      string
    Driver   string
    Version  string
    InstanceURL string
}

func (p *Profile) Validate() error {
    if p.Mode != "demo" && p.Mode != "dev" && p.Mode != "prod" {
        p.Mode = "demo"
    }

    if p.Mode == "prod" && p.Data == "" {
        p.Data = "/var/opt/appname"
    }

    if _, err := os.Stat(p.Data); err != nil {
        return err
    }

    if p.Driver == "sqlite" && p.DSN == "" {
        p.DSN = filepath.Join(p.Data, fmt.Sprintf("appname_%s.db", p.Mode))
    }

    return nil
}
```

## Related Skills

- [go-project-server](../go-project-server/) - Server implementation (Echo, cmux, dual protocol, interceptors)
- [go-project-store](../go-project-store/) - Database layer
- [go-project-proto](../go-project-proto/) - Protocol buffer definitions
- [go-project-overview](../go-project-overview/) - Project structure overview
