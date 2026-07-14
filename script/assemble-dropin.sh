#!/usr/bin/env bash
set -euo pipefail

# Assemble the app-map drop-in tarball from canonical source files.
# Usage: ./script/assemble-dropin.sh [--version <ver>]

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="dev"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

STAGING="$REPO_ROOT/_staging"
OUT="$STAGING/app-map"

echo "==> Building CLI (release, universal binary)…"
cd "$REPO_ROOT/cli"
swift build -c release --arch arm64 --arch x86_64
BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/appmap"
cd "$REPO_ROOT"

echo "==> Assembling drop-in at $OUT"
rm -rf "$STAGING"
mkdir -p "$OUT/bin" "$OUT/schema" "$OUT/skill" "$OUT/hooks"

cp "$BINARY"                            "$OUT/bin/appmap"
chmod +x                                "$OUT/bin/appmap"
cp "$REPO_ROOT/schema/surface.schema.json" "$OUT/schema/surface.schema.json"
cp "$REPO_ROOT/skill/SKILL.md"          "$OUT/skill/SKILL.md"
cp "$REPO_ROOT/install/hooks/pre-commit" "$OUT/hooks/pre-commit"
chmod +x                                "$OUT/hooks/pre-commit"
cp "$REPO_ROOT/install/INSTALL.md"      "$OUT/INSTALL.md"

TARBALL="$REPO_ROOT/app-map-v${VERSION}.tar.gz"
echo "==> Creating $TARBALL"
tar czf "$TARBALL" -C "$STAGING" app-map

rm -rf "$STAGING"
echo "==> Done: $TARBALL"
