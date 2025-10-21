# aichat Feature for Dev Containers

This feature installs aichat, a powerful AI chat client for your terminal.

Options

- `VERSION`: aichat version to install (default: latest)

Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/aichat:latest": {
    "VERSION": "latest"
  }
}
