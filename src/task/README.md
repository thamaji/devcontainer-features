# Task Feature for Dev Containers

This feature installs Task for task runner / build tool.

Options

- `VERSION`: Task version to install (default: latest)

Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/task:latest": {
    "VERSION": "latest"
  }
}
```
