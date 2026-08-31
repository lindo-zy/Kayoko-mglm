#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ -z "${THEOS:-}" || ! -d "${THEOS:-}" ]]; then
    THEOS="/Users/xiao/dev/theos-roothide"
fi
export THEOS
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

MAKE_BIN="$(command -v gmake || command -v make)"
PACKAGE_ID="$(awk -F': ' '/^Package:/{print $2; exit}' "$ROOT/control")"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [ios16|ios17|all]"
    exit 0
fi

BUILD_TARGET="${1:-all}"
case "$BUILD_TARGET" in
    ios16|ios17|all) ;;
    *)
        echo "Usage: $0 [ios16|ios17|all]" >&2
        exit 1
        ;;
esac

if [[ ! -d "$THEOS" ]]; then
    echo "error: RootHide Theos not found at $THEOS" >&2
    exit 1
fi

CURRENT_PACKAGE_VERSION="$(awk -F':=' '/PACKAGE_VERSION/{gsub(/[[:space:]]/, "", $2); print $2; exit}' "$ROOT/Makefile")"
if [[ ! "$CURRENT_PACKAGE_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "error: unsupported PACKAGE_VERSION: $CURRENT_PACKAGE_VERSION" >&2
    exit 1
fi

VERSION_MAJOR="${BASH_REMATCH[1]}"
VERSION_MINOR="${BASH_REMATCH[2]}"
VERSION_PATCH="${BASH_REMATCH[3]}"
PACKAGE_VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.$((10#$VERSION_PATCH + 1))"

persist_package_version() {
    OLD_VERSION="$CURRENT_PACKAGE_VERSION" NEW_VERSION="$PACKAGE_VERSION" perl -0pi -e '
        my $old = quotemeta($ENV{OLD_VERSION});
        s/^(export PACKAGE_VERSION := )$old$/$1$ENV{NEW_VERSION}/m
            or die "PACKAGE_VERSION line not found\n";
    ' "$ROOT/Makefile"
}

build_one() {
    local label="$1"
    local sdk_version="$2"
    local deployment_version="$3"
    local sdk_path="$THEOS/sdks/iPhoneOS${sdk_version}.sdk"
    local output_dir="$ROOT/packages/$label"
    local package_path="$ROOT/packages/${PACKAGE_ID}_${PACKAGE_VERSION}_iphoneos-arm64e.deb"
    local package_root
    local output_path="$output_dir/${PACKAGE_ID}_${PACKAGE_VERSION}_${label}_iphoneos-arm64e.deb"

    if [[ ! -d "$sdk_path" ]]; then
        echo "error: required SDK not found: $sdk_path" >&2
        exit 1
    fi

    echo "==> Building RootHide package for $label with iPhoneOS${sdk_version}.sdk"
    "$MAKE_BIN" clean >/dev/null
    THEOS_PACKAGE_SCHEME=roothide \
        TARGET="iphone:clang:${sdk_version}:${deployment_version}" \
        "$MAKE_BIN" package FINALPACKAGE=1 PACKAGE_VERSION="$PACKAGE_VERSION"

    mkdir -p "$output_dir"
    package_root="$(mktemp -d "${TMPDIR:-/tmp}/kayoko-package-${label}.XXXXXX")"
    dpkg-deb -R "$package_path" "$package_root" >/dev/null
    sed -i '' -E \
        "s/firmware \(>= [^)]+\)/firmware (>= ${deployment_version})/" \
        "$package_root/DEBIAN/control"
    dpkg-deb --build --root-owner-group "$package_root" "$output_path" >/dev/null
    echo "==> Output: $output_path"
}

echo "==> Package version: $CURRENT_PACKAGE_VERSION -> $PACKAGE_VERSION"

case "$BUILD_TARGET" in
    ios16)
        build_one ios16 16.5 16.0
        ;;
    ios17)
        build_one ios17 17.0 17.0
        ;;
    all)
        build_one ios16 16.5 16.0
        build_one ios17 17.0 17.0
        ;;
esac

persist_package_version
echo "==> Updated Makefile PACKAGE_VERSION to $PACKAGE_VERSION"
