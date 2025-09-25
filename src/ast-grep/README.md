# ast-grep Feature for Dev Containers

This feature installs ast-grep, a fast and powerful tool for code structural search, linting, and rewriting.

Options

- `VERSION`: ast-grep version to install (default: latest)

Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/ast-grep:latest": {
    "VERSION": "latest"
  }
}
```
