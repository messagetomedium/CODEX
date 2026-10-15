#!/usr/bin/env bash
set -euo pipefail

# Optional: run inside Codex Cloud Linux environment if Godot editor is absent.
# This script is not used by GitHub Actions: the Action uses a pinned godot-ci image.
VERSION="4.5.2"
RELEASE="stable"
TARGET="${HOME}/.local/bin"
TEMPLATES="${HOME}/.local/share/godot/export_templates/${VERSION}.${RELEASE}"
PREFIX="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-${RELEASE}"

if command -v godot >/dev/null 2>&1 && godot --headless --version | grep -q "^${VERSION}[.]" && test -f "${TEMPLATES}/web_release.zip"; then
    echo "Godot ${VERSION} and Web export templates are already installed."
    exit 0
fi

for command in curl unzip; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing dependency: $command" >&2
        exit 1
    fi
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
curl -fLS --retry 3 "${PREFIX}/Godot_v${VERSION}-${RELEASE}_linux.x86_64.zip" -o "${WORK_DIR}/godot.zip"
curl -fLS --retry 3 "${PREFIX}/Godot_v${VERSION}-${RELEASE}_export_templates.tpz" -o "${WORK_DIR}/templates.tpz"

unzip -q "${WORK_DIR}/godot.zip" -d "$WORK_DIR"
unzip -q "${WORK_DIR}/templates.tpz" -d "$WORK_DIR"
mkdir -p "$TARGET" "$TEMPLATES"
install -m 755 "${WORK_DIR}/Godot_v${VERSION}-${RELEASE}_linux.x86_64" "${TARGET}/godot"
cp -a "${WORK_DIR}/templates/." "$TEMPLATES/"
export PATH="${TARGET}:${PATH}"
printf 'Godot installed at %s\n' "${TARGET}/godot"
godot --headless --version
printf '%s\n' 'If future terminal sessions cannot find Godot, run: export PATH="$HOME/.local/bin:$PATH"'
