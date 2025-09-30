# cagent Feature for Dev Containers

This feature installs cagent.

Options

- `VERSION`: cagent version to install (default: latest)

Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/cagent:latest": {
    "VERSION": "latest"
  }
}
```
