# ace Feature for Dev Containers

This feature installs ace, a CLI tool that defines and runs AI agents from a single YAML file. Supports multi-agent setups and MCPServer.

Options

- `VERSION`: ace version to install (default: latest)

Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/ace:latest": {
    "VERSION": "latest"
  }
}
```
