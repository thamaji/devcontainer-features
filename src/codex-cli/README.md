# Codex CLI Feature for Dev Containers

This feature installs OpenAI Codex CLI and sets the API key from feature options.

## Options

- `OPENAI_API_KEY`: Your OpenAI API key (required for Codex CLI usage).

## Usage

In your `devcontainer.json`, add:

```json
"features": {
  "ghcr.io/thamaji/devcontainer-features/codex-cli:1": {
    "OPENAI_API_KEY": "your_api_key_here"
  }
}
```
