#!/bin/sh
set -e

echo "Installing lefthook..."

VERSION=${VERSION:-"latest"}

DISTRO=""
if [ -f /etc/alpine-release ]; then
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
  arm64)
    ARCH="arm64"
    ;;
  aarch64)
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
  require="ca-certificates curl gzip"
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

if command -v lefthook >/dev/null 2>&1; then
  # lefthook がすでにインストールされている場合は何もしない
  echo "lefthook is already installed. Skipping feature install."

else
  # latest バージョンを取得
  if [ "${VERSION}" = "latest" ]; then
    VERSION=$(
      curl -fsSL https://api.github.com/repos/evilmartians/lefthook/releases/latest \
      | grep '"tag_name":' \
      | sed -E 's/.*"([^\"]+)".*/\1/'
    )
  fi

  # lefthook をインストール
  echo download lefthook: "https://github.com/evilmartians/lefthook/releases/download/${VERSION}/lefthook_${VERSION#v}_Linux_$(uname -m).gz"
  curl -fsSL "https://github.com/evilmartians/lefthook/releases/download/${VERSION}/lefthook_${VERSION#v}_Linux_$(uname -m).gz" \
    | gunzip > /usr/local/bin/lefthook
  chmod +x /usr/local/bin/lefthook

fi

# postCreateCommand 用のスクリプトを作成
# .git と .lefthook.yml が存在するなら、コンテナの作成後に lefthook install を実行する。
mkdir -p /usr/local/lefthook
cat <<EOF >/usr/local/lefthook/setup.sh
#!/bin/sh
set -e
if [ ! -d .git ]; then
  exit
fi

for file in lefthook.yml .lefthook.yml .config/lefthook.yml lefthook.yaml .lefthook.yaml .config/lefthook.yaml lefthook.toml .lefthook.toml .config/lefthook.toml lefthook.json .lefthook.json .config/lefthook.json; do
  if [ -f "\${file}" ]; then
    lefthook install
    break
  fi
done
EOF
chmod +x /usr/local/lefthook/setup.sh

echo "lefthook installed successfully."
