#!/bin/sh
set -e

echo "Installing Codex CLI..."

VERSION=${VERSION:-"latest"}
OPENAI_API_KEY=${OPENAI_API_KEY:-""}
INSTALL_DIR="/usr/local"

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
  recommends="coreutils findutils grep ripgrep sed" # Codex のホワイトリストコマンドを提供するパッケージ
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

# latest バージョンを取得
if [ "${VERSION}" = "latest" ]; then
  VERSION=$(
    curl -fsSL https://api.github.com/repos/openai/codex/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/'
  )
fi

# Codex CLIをダウンロード
mkdir -p "${INSTALL_DIR}/codex-cli"
curl -fsSL "https://github.com/openai/codex/releases/download/${VERSION}/codex-${ARCH}-unknown-linux-musl.tar.gz" \
  | tar -xz -C "${INSTALL_DIR}/codex-cli"

# OPENAI_API_KEY を仕込んだラッパースクリプトをつくる
mkdir -p "${INSTALL_DIR}/bin"
cat <<EOF > "${INSTALL_DIR}/bin/codex"
#!/bin/sh
export OPENAI_API_KEY="${OPENAI_API_KEY}"
exec ${INSTALL_DIR}/codex-cli/codex-${ARCH}-unknown-linux-musl "\$@"
EOF
chmod +x "${INSTALL_DIR}/bin/codex"

echo "Codex CLI installed successfully."
