#!/usr/bin/env bash
#
# cstar installer for macOS and Linux.
#
# Usage:
#   curl -fsSL https://stonebuddha.github.io/install/unix.sh | bash
#   curl -fsSL https://stonebuddha.github.io/install/unix.sh | bash -s -- v0.5.0rc1
#
# Environment variables:
#   CSTAR_INSTALL_VERSION   Version to install, e.g. "v0.5.0rc1" (overridden by the first argument; defaults to "latest").
#   CSTAR_INSTALL_BASE_URL  Base URL that hosts the release tarballs.
#   CSTAR_INSTALL_LATEST_URL  URL of a file containing the latest version number (used when installing "latest").
#   CSTAR_HOME              Install location (defaults to ~/.cstar).

set -euo pipefail

######## colored output (taken from install.sh) ########

# Reset
Color_Off=''

# Regular Colors
Red=''
Green=''
Dim='' # White

# Bold
Bold_White=''
Bold_Green=''

if [[ -t 1 ]]; then
    # Reset
    Color_Off='\033[0m' # Text Reset

    # Regular Colors
    Red='\033[0;31m'   # Red
    Green='\033[0;32m' # Green
    Dim='\033[0;2m'    # White

    # Bold
    Bold_Green='\033[1;32m' # Bold Green
    Bold_White='\033[1m'    # Bold White
fi

error() {
    echo -e "${Red}error${Color_Off}:" "$@" >&2
    exit 1
}

info() {
    echo -e "${Dim}$@ ${Color_Off}"
}

info_bold() {
    echo -e "${Bold_White}$@ ${Color_Off}"
}

success() {
    echo -e "${Green}$@ ${Color_Off}"
}

######## check dependencies ########

command -v curl >/dev/null 2>&1 ||
    error "curl is required to install cstar"

command -v tar >/dev/null 2>&1 ||
    error "tar is required to install cstar"

######## check platform ########

target=''

case $(uname -ms) in
'Darwin x86_64')
    target=darwin-x64
    ;;
'Darwin arm64')
    target=darwin-aarch64
    ;;
'Linux x86_64')
    target=linux-x64
    ;;
*)
    error "Unsupported platform: $(uname -ms)"
    ;;
esac

######## resolve version and download url ########

# Version can be passed as the first argument or via CSTAR_INSTALL_VERSION.
# Defaults to "latest", which resolves to the newest release.
version="${1:-${CSTAR_INSTALL_VERSION:-latest}}"

# The release host (Gitee) has no "latest" alias, so "latest" is resolved to a
# concrete version number published at a well-known URL.
latest_url="${CSTAR_INSTALL_LATEST_URL:-https://stonebuddha.github.io/install/latest}"

if [[ $version == "latest" ]]; then
    info "Resolving the latest version ..."
    version=$(curl --fail --silent --show-error --location "$latest_url" | tr -d '[:space:]') ||
        error "Failed to resolve the latest version from \"$latest_url\""
    [[ -n $version ]] ||
        error "The latest version file at \"$latest_url\" is empty"
fi

# Accept both "0.5.0rc1" and "v0.5.0rc1"; normalize to a leading "v".
version="v${version#v}"

base_url="${CSTAR_INSTALL_BASE_URL:-https://gitee.com/cstarlang/cstar_ide/releases/download}"
archive_name="cstar_${target}.tar.xz"
download_url="$base_url/$version/$archive_name"

######## download and extract ########

tmp_dir=$(mktemp -d) ||
    error "Failed to create a temporary directory"

# Clean up the temporary directory on exit, whatever the outcome.
trap 'rm -rf "$tmp_dir"' EXIT

archive_path="$tmp_dir/$archive_name"

info "Downloading cstar $version for $target ..."

curl --fail --location --progress-bar --output "$archive_path" "$download_url" ||
    error "Failed to download cstar from \"$download_url\""

info "Extracting ..."

tar -xJf "$archive_path" -C "$tmp_dir" ||
    error "Failed to extract \"$archive_path\""

######## run the bundled install.sh ########

# The tarball extracts to a directory (e.g. cstar_v0.5.0rc1_darwin-aarch64/)
# that contains bin/, lib/, include/ and the packaged install.sh.
install_script=$(find "$tmp_dir" -maxdepth 2 -name install.sh -type f | head -n 1)

if [[ -z $install_script ]]; then
    error "Could not find install.sh in the downloaded archive"
fi

install_root=$(dirname "$install_script")

pushd "$install_root" >/dev/null ||
    error "Failed to change directory to \"$install_root\""

    bash ./install.sh ||
        error "install.sh failed"

popd >/dev/null || error "Failed to change directory to previous one"
