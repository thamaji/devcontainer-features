#!/bin/sh
set -eu

# devcontainer feature の options
VERSION=${VERSION:-"latest"}

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
echo "Installing ast-grep(sg)..."

# ast-grep(sg) がすでにインストールされている場合は何もしない
if command -v ast-grep >/dev/null 2>&1; then
  echo "ast-grep(sg) is already installed. Skipping feature install."
  exit 0
fi

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
    echo "Unsupported architecture: ${arch}" >&2
    exit 1
    ;;
esac

# install.sh の実行に必要なパッケージのインストール
case "${distro}" in
  alpine)
    packages="ca-certificates unzip"
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
      packages="curl ${packages}"
    fi
    apk_install ${packages}
    ;;

  debian | ubuntu)
    packages="ca-certificates unzip"
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
      packages="curl ${packages}"
    fi
    apt_install ${packages}
    ;;

  *)
    echo "Unsupported distribution" >&2
    exit 1
    ;;
esac

# latest バージョンを取得
if [ "${VERSION}" = "latest" ]; then
  VERSION=$(
    download https://api.github.com/repos/ast-grep/ast-grep/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/'
  )
  if [ -z "${VERSION}" ]; then
    echo "latest version could not be determined" >&2
    exit 1
  fi
fi

# ast-grep(sg) をインストール
download_url="https://github.com/ast-grep/ast-grep/releases/download/${VERSION}/app-${arch}-unknown-linux-gnu.zip"
install_dir="/usr/local/ast-grep-${VERSION}"
echo download ast-grep: "${download_url}"
mkdir -p "${install_dir}"
download "${download_url}" > "${install_dir}/app-${arch}-unknown-linux-gnu.zip"
unzip "${install_dir}/app-${arch}-unknown-linux-gnu.zip" -d "${install_dir}"
rm "${install_dir}/app-${arch}-unknown-linux-gnu.zip"
ln -snf "${install_dir}/ast-grep" /usr/local/bin/ast-grep
ln -snf "${install_dir}/sg" /usr/local/bin/sg

echo "ast-grep(sg) installed successfully."
