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
echo "Installing cagent..."

# cagent がすでにインストールされている場合は何もしない
if command -v cagent >/dev/null 2>&1; then
  echo "cagent is already installed. Skipping feature install."
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
    arch="amd64"
    ;;
  aarch64 | arm64)
    arch="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${arch}"
    exit 1
    ;;
esac

# install.sh の実行に必要なパッケージをインストール
case "${distro}" in
  alpine)
    packages="ca-certificates"
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
      packages="${packages} curl"
    fi
    apk_install ${packages}
    ;;

  debian | ubuntu)
    packages="ca-certificates"
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
      packages="${packages} curl"
    fi
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
    download https://api.github.com/repos/docker/cagent/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/'
  )
fi

# cagent をインストール
download_url="https://github.com/docker/cagent/releases/download/${VERSION}/cagent-linux-${arch}"
install_dir="/usr/local/cagent-${VERSION}"
echo download cagent: "${download_url}"
mkdir -p "${install_dir}"
download "${download_url}" > "${install_dir}/cagent-linux-${arch}"
chmod +x "${install_dir}/cagent-linux-${arch}"
ln -s "${install_dir}/cagent-linux-${arch}" /usr/local/bin/cagent

echo "cagent installed successfully."
