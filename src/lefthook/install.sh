#!/bin/sh
set -e

echo "Installing lefthook..."

VERSION=${VERSION:-"latest"}
INSTALL_DIR="/usr/local"

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

# Install required packages on Debian/Ubuntu
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

# If already installed, skip
if command -v lefthook >/dev/null 2>&1; then
  echo "lefthook is already installed. Skipping feature install."
  exit 0
fi

# Determine latest version if requested
if [ "${VERSION}" = "latest" ]; then
  VERSION=$(
    curl -fsSL https://api.github.com/repos/evilmartians/lefthook/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^\"]+)".*/\1/'
  )
fi

# Download and install lefthook
curl -fsSL "https://github.com/evilmartians/lefthook/releases/download/${VERSION}/lefthook_${VERSION#v}_Linux_$(uname -m).gz" \
  | gunzip > "${INSTALL_DIR}/bin/lefthook"
chmod +x "${INSTALL_DIR}/bin/lefthook"

echo "lefthook installed successfully."
