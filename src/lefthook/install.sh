#!/bin/sh
set -e

# devcontainer feature の options
VERSION=${VERSION:-"latest"}
if [ "${VERSION}" != "latest" ] && [ "${VERSION#v}" = "${VERSION}" ]; then
  VERSION="v${VERSION}"
fi

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

# JSONから特定のキーの値を抽出する関数
# perl または jq が必要
get_json_value() {
  local _key="$1"

  if perl -MJSON::PP -e1 2>/dev/null; then
    perl -MJSON::PP -0777 -ne '
    my $j = decode_json($_);
    print $j->{"'"$_key"'"} // "";
    '
  elif command -v jq >/dev/null 2>&1; then
    jq -r ".${_key} // empty"
  else
    echo "error: perl or jq required" >&2
    exit 1
  fi
}

# インストールを開始
echo "Installing lefthook..."

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
    arch="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${arch}" >&2
    exit 1
    ;;
esac

if command -v lefthook >/dev/null 2>&1; then
  # lefthook がすでにインストールされている場合は何もしない
  echo "lefthook is already installed. Skipping feature install."

else
  # install.sh の実行に必要なパッケージのインストール
  case "${distro}" in
    alpine)
      packages="ca-certificates gzip"
      if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        packages="curl ${packages}"
      fi
      if ! perl -MJSON::PP -e1 2>/dev/null && ! command -v jq >/dev/null 2>&1; then
        packages="jq ${packages}"
      fi
      apk_install ${packages}
      ;;

    debian | ubuntu)
      packages="ca-certificates gzip"
      if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        packages="curl ${packages}"
      fi
      if ! perl -MJSON::PP -e1 2>/dev/null && ! command -v jq >/dev/null 2>&1; then
        packages="jq ${packages}"
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
      download https://api.github.com/repos/evilmartians/lefthook/releases/latest \
      | get_json_value tag_name
    )
    if [ -z "${VERSION}" ]; then
      echo "latest version could not be determined" >&2
      exit 1
    fi
  fi

  # lefthook をインストール
  download_url="https://github.com/evilmartians/lefthook/releases/download/${VERSION}/lefthook_${VERSION#v}_Linux_${arch}.gz"
  echo download lefthook: "${download_url}"
  mkdir -p /usr/local/bin
  download "${download_url}" | gunzip > /usr/local/bin/lefthook
  chmod +x /usr/local/bin/lefthook

  echo "lefthook installed successfully."
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
