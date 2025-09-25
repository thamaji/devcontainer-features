#!/bin/sh
set -e

echo "Installing ast-grep(sg)..."

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
  require="ca-certificates curl unzip"
  installed=$(dpkg -l | awk '/^ii/ { print $2 }')
  missing=""
  for package in ${require}; do
    echo "${installed}" | grep -q "^${package}$" || missing="$missing ${package}"
  done

  if [ -n "${missing}" ]; then
    apt-get update
    apt-get install -y --no-install-recommends ${missing}
  fi

else
  echo "Unsupported distribution"
  exit 1
fi

if command -v ast-grep >/dev/null 2>&1; then
  # ast-grep(sg) がすでにインストールされている場合は何もしない
  echo "ast-grep(sg) is already installed. Skipping feature install."
  exit 0
fi


# latest バージョンを取得
if [ "${VERSION}" = "latest" ]; then
  VERSION=$(
    curl -fsSL https://api.github.com/repos/ast-grep/ast-grep/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/'
  )
fi

# ast-grep(sg) をインストール
echo download Codex CLI: "https://github.com/ast-grep/ast-grep/releases/download/${VERSION}/app-${ARCH}-unknown-linux-gnu.zip"
install_dir="/usr/local/ast-grep-${VERSION}"
mkdir -p "${install_dir}"
curl -fsSL -o "${install_dir}/app-${ARCH}-unknown-linux-gnu.zip" "https://github.com/ast-grep/ast-grep/releases/download/${VERSION}/app-${ARCH}-unknown-linux-gnu.zip"
unzip "${install_dir}/app-${ARCH}-unknown-linux-gnu.zip" -d "${install_dir}"
rm "${install_dir}/app-${ARCH}-unknown-linux-gnu.zip"
ln -s "${install_dir}/ast-grep" /usr/local/bin/ast-grep
ln -s "${install_dir}/sg" /usr/local/bin/sg

echo "ast-grep(sg) installed successfully."
