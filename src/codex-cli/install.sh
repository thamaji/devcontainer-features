#!/bin/sh
set -e

# devcontainer feature の options
VERSION=${VERSION:-"latest"}
OPENAI_API_KEY=${OPENAI_API_KEY:-""}

# 関数定義

# alpine 向けのパッケージインストール関数
apk_install() {
  _apk_install_package_list=""
  for _apk_install_package in "${@}"; do
    if ! apk info -e "${_apk_install_package}" > /dev/null 2>&1 || [ "${_apk_install_package}" = "ca-certificates" ]; then
      _apk_install_package_list="${_apk_install_package_list} ${_apk_install_package}"
    fi
  done

  if [ -n "${_apk_install_package_list}" ]; then
    apk update
    apk add --no-cache ${_apk_install_package_list}
  fi
}

# debian, ubuntu 向けのパッケージインストール関数
apt_install() {
  _apt_install_package_list=""
  for _apt_install_package in "${@}"; do
    if ! dpkg -l "${_apt_install_package}" > /dev/null 2>&1 || [ "${_apt_install_package}" = "ca-certificates" ]; then
      _apt_install_package_list="${_apt_install_package_list} ${_apt_install_package}"
    fi
  done

  if [ -n "${_apt_install_package_list}" ]; then
    apt-get update
    apt-get install -y --no-install-recommends ${_apt_install_package_list}
  fi
}

# curl もしくは wget でインターネットからリソースをダウンロードする関数
download() {
  _download_url="${1}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${_download_url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "${_download_url}"
  else
    return 1
  fi
}

# インストールを開始
echo "Installing Codex CLI..."

# ディストリビューションの特定
distro=""
if [ -f  /etc/alpine-release ]; then
  distro="alpine"
elif [ -f /etc/debian_version ]; then
  distro="debian"
elif [ -f /etc/os-release ]; then
  distro=$(. /etc/os-release && echo "${ID}")
fi

# アーキテクチャの特定
arch=$(uname -m)
case "${arch}" in
  x86_64 | amd64)
    arch="x86_64"
    ;;
  aarch64 | arm64)
    arch="aarch64"
    ;;
  *)
    echo "Unsupported architecture: ${arch}"
    exit 1
    ;;
esac

if command -v codex >/dev/null 2>&1; then
  # Codex CLI がすでにインストールされている場合、Codex CLI のインストールはしない
  echo "Codex CLI is already installed. Skipping feature install."

  # Codex CLI が利用する推奨パッケージのインストール
  case "${distro}" in
    alpine)
      apk_install coreutils fd findutils gawk grep ripgrep sed
      ;;

    debian | ubuntu)
      apt_install coreutils fd-find findutils gawk grep ripgrep sed
      ;;

    *)
      echo "Unsupported distribution"
      exit 1
      ;;
  esac

else
  # install.sh の実行に必要なパッケージと Codex CLI が利用する推奨パッケージのインストール
  case "${distro}" in
    alpine)
      packages="ca-certificates tar"
      if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        packages="curl ${packages}"
      fi
      packages="coreutils fd findutils gawk grep ripgrep sed ${packages}"
      apk_install ${packages}
      ;;

    debian | ubuntu)
      packages="ca-certificates tar"
      if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        packages="curl ${packages}"
      fi
      packages="coreutils fd-find findutils gawk grep ripgrep sed ${packages}"
      apt_install ${packages}
      ;;

    *)
      echo "Unsupported distribution"
      exit 1
      ;;
  esac

  # latest バージョンを取得
  if [ "${VERSION}" = "latest" ]; then
    VERSION=$(
      download https://api.github.com/repos/openai/codex/releases/latest \
      | grep '"tag_name":' \
      | sed -E 's/.*"([^"]+)".*/\1/'
    )
  fi

  # Codex CLIをインストール
  download_url="https://github.com/openai/codex/releases/download/${VERSION}/codex-${arch}-unknown-linux-musl.tar.gz"
  echo download Codex CLI: "${download_url}"
  mkdir -p /usr/local/codex-cli
  download "${download_url}" | tar -xz -C /usr/local/codex-cli
  mkdir -p /usr/local/bin
  ln -s /usr/local/codex-cli/codex-${arch}-unknown-linux-musl /usr/local/bin/codex

  echo "Codex CLI installed successfully."
fi

# postCreateCommand 用のスクリプトを作成
# OPENAI_API_KEY が指定されていれば、devcontainer の作成後に API Key でのログインを実行する。
# ~/.codex が無い場合に login が失敗する（おそらくバグ）のであらかじめつくっておく。
mkdir -p /usr/local/codex-cli
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
