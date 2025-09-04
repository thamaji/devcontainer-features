# Lefthook Feature for Dev Containers

This feature installs Lefthook, a fast and powerful Git hooks manager.

Options

- `LEFTHOOK_VERSION`: Lefthook version to install (default: latest)

Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/lefthook:1": {
    "LEFTHOOK_VERSION": "latest"
  }
}
```
