#!/bin/sh
set -e

# devcontainer feature の options
VERSION=${VERSION:-"latest"}
if [ "${VERSION}" != "latest" ] && [ "${VERSION#rust-v}" = "${VERSION}" ]; then
  VERSION="rust-v${VERSION}"
fi
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
    if ! dpkg-query -W -f='${Status}' "${_apt_install_package}" 2>/dev/null | grep -q "install ok installed" \
       || [ "${_apt_install_package}" = "ca-certificates" ]; then
      _apt_install_package_list="${_apt_install_package_list} ${_apt_install_package}"
    fi
  done

  if [ -n "${_apt_install_package_list}" ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${_apt_install_package_list}
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
    echo "Neither curl nor wget is available to download ${_download_url}." >&2
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

if command -v codex >/dev/null 2>&1; then
  # Codex CLI がすでにインストールされている場合、Codex CLI のインストールはしない
  echo "Codex CLI is already installed. Skipping feature install."

  # Codex CLI が利用する推奨パッケージのインストール
  case "${distro}" in
    alpine)
      apk_install ack bubblewrap ca-certificates coreutils fd findutils gawk grep ripgrep sed the_silver_searcher tree
      ;;

    debian | ubuntu)
      apt_install ack bubblewrap ca-certificates coreutils fd-find findutils gawk grep ripgrep sed silversearcher-ag tree

      if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        ln -sf "$(command -v fdfind)" /usr/local/bin/fd
      fi
      ;;

    *)
      echo "Unsupported distribution" >&2
      exit 1
      ;;
  esac

else
  # install.sh の実行に必要なパッケージと Codex CLI が利用する推奨パッケージのインストール
  case "${distro}" in
    alpine)
      packages="ca-certificates coreutils procps tar util-linux"
      if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        packages="curl ${packages}"
      fi
      packages="ack bubblewrap fd findutils gawk grep ripgrep sed the_silver_searcher tree ${packages}"
      apk_install ${packages}
      ;;

    debian | ubuntu)
      packages="ca-certificates coreutils procps tar util-linux"
      if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        packages="curl ${packages}"
      fi
      packages="ack bubblewrap fd-find findutils gawk grep ripgrep sed silversearcher-ag tree ${packages}"
      apt_install ${packages}

      if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        ln -sf "$(command -v fdfind)" /usr/local/bin/fd
      fi
      ;;

    *)
      echo "Unsupported distribution"
      exit 1
      ;;
  esac

  # Codex CLIをインストール
  download https://chatgpt.com/codex/install.sh | \
    CODEX_RELEASE="${VERSION#rust-v}" \
    CODEX_NON_INTERACTIVE=1 \
    sh

  echo "Codex CLI installed successfully."
fi

# postCreateCommand 用のスクリプトを作成
# OPENAI_API_KEY が指定されていれば、devcontainer の作成後に API Key でのログインを実行する。
mkdir -p /usr/local/codex-cli
cat <<EOF >/usr/local/codex-cli/setup.sh
#!/bin/sh
set -e
if [ ! -z "${OPENAI_API_KEY}" ]; then
  echo "${OPENAI_API_KEY}" | codex login --with-api-key
fi
EOF
chmod +x /usr/local/codex-cli/setup.sh
