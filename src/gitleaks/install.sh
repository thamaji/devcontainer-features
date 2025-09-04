#!/bin/sh
set -e

echo "Installing gitleaks..."

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
    ARCH="x64"
    ;;
  aarch64 | arm64)
    ARCH="arm64"
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
  require="ca-certificates curl gzip tar"
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
if command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks is already installed. Skipping feature install."
  exit 0
fi

# Determine latest version if requested
if [ "${VERSION}" = "latest" ]; then
  VERSION=$(
    curl -fsSL https://api.github.com/repos/zricethezav/gitleaks/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^\"]+)".*/\1/'
  )
fi

# Download and install gitleaks
mkdir -p "${INSTALL_DIR}/gitleaks"
curl -fsSL "https://github.com/zricethezav/gitleaks/releases/download/${VERSION}/gitleaks_${VERSION#v}_linux_${ARCH}.tar.gz" \
  | tar -xz -C "${INSTALL_DIR}/bin" gitleaks

echo "gitleaks installed successfully."
