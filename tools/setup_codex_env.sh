#!/usr/bin/env bash
set -euo pipefail

# Godot standard + the non-threaded Web templates only. No project files changed.
VERSION="4.5.2"
RELEASE="stable"
TARGET="${GODOT_INSTALL_DIR:-${HOME}/.local/bin}"
TEMPLATES="${XDG_DATA_HOME:-${HOME}/.local/share}/godot/export_templates/${VERSION}.${RELEASE}"
PREFIX="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-${RELEASE}"
ENGINE_ARCHIVE="Godot_v${VERSION}-${RELEASE}_linux.x86_64.zip"
TEMPLATE_ARCHIVE="Godot_v${VERSION}-${RELEASE}_export_templates.tpz"

GODOT_CANDIDATE="$(command -v godot || true)"
if test -x "${TARGET}/godot"; then GODOT_CANDIDATE="${TARGET}/godot"; fi
if test -n "$GODOT_CANDIDATE" && "$GODOT_CANDIDATE" --headless --version | grep -q "^4[.]5[.]2[.]stable[.]" \
    && test -f "${TEMPLATES}/web_nothreads_release.zip" && test -f "${TEMPLATES}/web_nothreads_debug.zip"; then
    echo "Godot ${VERSION} and non-threaded Web export templates are already installed."
    exit 0
fi
for dependency in curl unzip sha512sum; do
    command -v "$dependency" >/dev/null 2>&1 || { echo "Missing dependency: $dependency" >&2; exit 1; }
done
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
curl -fLS --retry 3 "${PREFIX}/SHA512-SUMS.txt" -o "${WORK_DIR}/SHA512-SUMS.txt"
curl -fLS --retry 3 "${PREFIX}/${ENGINE_ARCHIVE}" -o "${WORK_DIR}/${ENGINE_ARCHIVE}"
curl -fLS --retry 3 "${PREFIX}/${TEMPLATE_ARCHIVE}" -o "${WORK_DIR}/${TEMPLATE_ARCHIVE}"
(
    cd "$WORK_DIR"
    awk -v engine="$ENGINE_ARCHIVE" -v templates="$TEMPLATE_ARCHIVE" '$2 == engine || $2 == templates' SHA512-SUMS.txt > selected.sha512
    test "$(wc -l < selected.sha512)" -eq 2
    sha512sum --check selected.sha512
)
unzip -q "${WORK_DIR}/${ENGINE_ARCHIVE}" -d "$WORK_DIR"
mkdir -p "$TARGET" "$TEMPLATES"
install -m 755 "${WORK_DIR}/Godot_v${VERSION}-${RELEASE}_linux.x86_64" "${TARGET}/godot"
unzip -q -o -j "${WORK_DIR}/${TEMPLATE_ARCHIVE}" 'templates/web_nothreads_*.zip' 'templates/version.txt' -d "$TEMPLATES"
"${TARGET}/godot" --headless --version
printf 'Godot installed at %s; add this directory to PATH for future shells.\n' "$TARGET"
