# Codex CLI Feature for Dev Containers

This feature installs OpenAI Codex CLI and sets the API key from feature options.

## Options

- `OPENAI_API_KEY`: Your OpenAI API key (required for Codex CLI usage).
- `VERSION`: Codex CLI version (default: `latest`).

## Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/codex-cli:latest": {
    "OPENAI_API_KEY": "your_api_key_here",
    "VERSION": "latest"
  }
}
```
