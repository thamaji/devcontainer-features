# Gitleaks Feature for Dev Containers

This feature installs gitleaks for scanning repositories for secrets.

Options

- `VERSION`: gitleaks version to install (default: latest)

Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/gitleaks:1": {
    "VERSION": "latest"
  }
}
```
