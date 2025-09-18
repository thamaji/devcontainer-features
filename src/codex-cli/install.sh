#!/bin/sh
set -e

echo "Installing Codex CLI..."

VERSION=${VERSION:-"latest"}
OPENAI_API_KEY=${OPENAI_API_KEY:-""}

DISTRO=""
if [ -f  /etc/alpine-release ]; then
  DISTRO="alpine"
elif [ -f /etc/debian_version ]; then
  DISTRO="debian"
elif [ -f /etc/os-release ]; then
  DISTRO=$(. /etc/os-release && echo "${ID}")
fi

ARCH=$(uname -m)
case "$ARCH" in
  x86_64 | amd64)
    ARCH="x86_64"
    ;;
  aarch64 | arm64)
    ARCH="aarch64"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

# 依存・推奨パッケージのインストール
if [ "${DISTRO}" = "alpine" ]; then
  echo "Unsupported distribution"
  exit 1

elif [ "${DISTRO}" = "debian" ] || [ "${DISTRO}" = "ubuntu" ]; then
  recommends="coreutils fd-find findutils gawk grep ripgrep sed" # Codex のホワイトリストコマンドを提供するパッケージ
  require="ca-certificates curl tar" # インストールに必要なパッケージ
  installed=$(dpkg -l | awk '/^ii/ { print $2 }')
  missing=""
  for package in ${require} ${recommends}; do
    echo "${installed}" | grep -q "^${package}\$" || missing="$missing ${package}"
  done

  if [ -n "${missing}" ]; then
    apt-get update
    apt-get install -y --no-install-recommends ${missing}
  fi

else
  echo "Unsupported distribution"
  exit 1
fi

if command -v codex >/dev/null 2>&1; then
  # Codex CLI がすでにインストールされている場合は何もしない
  echo "Codex CLI is already installed. Skipping feature install."

else
  # latest バージョンを取得
  if [ "${VERSION}" = "latest" ]; then
    VERSION=$(
      curl -fsSL https://api.github.com/repos/openai/codex/releases/latest \
      | grep '"tag_name":' \
      | sed -E 's/.*"([^"]+)".*/\1/'
    )
  fi

  # Codex CLIをインストール
  echo download Codex CLI: "https://github.com/openai/codex/releases/download/${VERSION}/codex-${ARCH}-unknown-linux-musl.tar.gz"
  mkdir -p /usr/local/codex-cli
  curl -fsSL "https://github.com/openai/codex/releases/download/${VERSION}/codex-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/codex-cli
  mkdir -p /usr/local/bin
  ln -s /usr/local/codex-cli/codex-x86_64-unknown-linux-musl /usr/local/bin/codex

fi

# postCreateCommand 用のスクリプトを作成
# OPENAI_API_KEY が指定されていれば、devcontainer の作成後に API Key でのログインを実行する。
# ~/.codex が無い場合に login が失敗する（おそらくバグ）のであらかじめつくっておく。
cat <<EOF >/usr/local/codex-cli/setup.sh
#!/bin/sh
set -e
if [ -z "${OPENAI_API_KEY}" ]; then
  exit
fi
mkdir -p ~/.codex
codex login --api-key "${OPENAI_API_KEY}"
EOF
chmod +x /usr/local/codex-cli/setup.sh

echo "Codex CLI installed successfully."
