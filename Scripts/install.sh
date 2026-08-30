#!/usr/bin/env bash
#
# Otium installer — one line, no Xcode, no build.
#
#   curl -fsSL https://raw.githubusercontent.com/xmasyx/otium/main/Scripts/install.sh | bash
#
# Downloads the latest release, puts Otium.app in /Applications and clears the
# quarantine flag: releases are signed with the project's own certificate, not notarized.
# Then it launches the app.
#
#   install.sh              install or update to the latest release
#   install.sh --version X  install a specific tag (e.g. v1.0.0)
#   install.sh --uninstall  remove the app (your log and settings are kept)
#   install.sh --purge      remove the app AND its log + settings
#
# Override the source repo for testing:  OTIUM_REPO=you/fork ./install.sh
set -euo pipefail

REPO="${OTIUM_REPO:-xmasyx/otium}"
APP_NAME="Otium"
BUNDLE_ID="app.otium.mac"
SUPPORT_DIR="${HOME}/Library/Application Support/${APP_NAME}"

say()  { printf '\033[1m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ── Where does the app live? /Applications, or ~/Applications if that's read-only
install_dir() {
    if [ -w "/Applications" ]; then echo "/Applications"
    else mkdir -p "${HOME}/Applications"; echo "${HOME}/Applications"; fi
}

# ── Removing a bundle is the one destructive act here. Refuse anything that is
#    not literally an existing directory named Otium.app, so a mistyped or empty
#    variable can never widen into deleting a directory we did not create.
remove_bundle() {
    local target="$1"
    [ -n "${target}" ]                  || die "internal: empty removal target"
    [ "$(basename "${target}")" = "${APP_NAME}.app" ] \
                                        || die "internal: refusing to remove ${target}"
    [ -d "${target}" ]                  || return 0
    rm -rf "${target}"
}

quit_running() {
    if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
        say "quitting the running ${APP_NAME}…"
        osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
        sleep 1
        pkill -x "${APP_NAME}" >/dev/null 2>&1 || true
    fi
}

uninstall() {
    local purge="${1:-no}"
    quit_running
    local dir; dir="$(install_dir)"
    remove_bundle "${dir}/${APP_NAME}.app"
    ok "removed ${dir}/${APP_NAME}.app"
    if [ "${purge}" = "purge" ]; then
        defaults delete "${BUNDLE_ID}" >/dev/null 2>&1 || true
        [ -d "${SUPPORT_DIR}" ] && rm -rf "${SUPPORT_DIR}"
        ok "removed settings and the activity log"
    else
        # The log is the only copy of what you did — deleting it by default would
        # throw away months of history to save a few kilobytes.
        printf '  settings and your log are kept in %s\n' "${SUPPORT_DIR}"
        printf '  (remove them too with: %s --purge)\n' "$(basename "$0")"
    fi
    exit 0
}

# ── Arguments
TAG=""
case "${1:-}" in
    --uninstall) uninstall ;;
    --purge)     uninstall purge ;;
    --version)   TAG="${2:-}"; [ -n "${TAG}" ] || die "--version needs a tag, e.g. --version v1.0.0" ;;
    "")          ;;
    *)           die "unknown option: $1" ;;
esac

# ── Requirements. Otium is built against the macOS 15 SDK and for arm64, so
#    macOS 15 and Apple Silicon are the two hard requirements checked here.
#
#    About the processor: the release carries exactly arm64 and Otium runs on
#    Apple Silicon. Intel Macs are refused here, before any release is looked up
#    or downloaded. The downloaded bundle is still asked to run before anything
#    is copied; that probe catches a broken build on a supported Mac.
say "checking this Mac…"

[ "$(uname -s)" = "Darwin" ] || die "Otium is macOS only."

if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" != "1" ]; then
    die "Otium needs Apple Silicon (M1 or newer). This Mac is Intel; Otium runs on Apple Silicon only."
fi

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "${macos_major}" -lt 15 ]; then
    die "Otium needs macOS 15 or newer (this Mac runs $(sw_vers -productVersion))."
fi
ok "$(sw_vers -productVersion), Apple Silicon"

# ── Find the release
if [ -n "${TAG}" ]; then
    API="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
else
    API="https://api.github.com/repos/${REPO}/releases/latest"
fi

say "looking up the release…"
RELEASE_JSON="$(curl -fsSL "${API}" 2>/dev/null)" \
    || die "could not reach GitHub, or ${REPO} has no ${TAG:-published release} yet."

# Grab the first .zip asset. Plain sed rather than jq — an installer must not
# require the user to install a JSON parser first.
ASSET_URL="$(printf '%s' "${RELEASE_JSON}" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' \
    | head -1 | sed 's/.*"browser_download_url": *"//; s/"$//')"
VERSION="$(printf '%s' "${RELEASE_JSON}" \
    | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*: *"//; s/"$//')"

[ -n "${ASSET_URL}" ] || die "that release has no .zip asset attached."
ok "found ${VERSION}"

# ── Download into a temp dir that is always cleaned up, even on failure
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

say "downloading…"
curl -fL# "${ASSET_URL}" -o "${TMP}/${APP_NAME}.zip" || die "download failed."

say "unpacking…"
ditto -x -k "${TMP}/${APP_NAME}.zip" "${TMP}/unpacked" || die "the archive is corrupt."

SRC="${TMP}/unpacked/${APP_NAME}.app"
[ -d "${SRC}" ] || die "the archive does not contain ${APP_NAME}.app."
[ -x "${SRC}/Contents/MacOS/${APP_NAME}" ] || die "the downloaded bundle has no executable."

# ── Does this build run on THIS Mac? Asked before /Applications is touched.
#
# The check that answers this used to live at the very end, after the copy, and when it failed
# it blamed the quarantine flag: "the installed app does not run. Try: xattr -cr". On an
# unsupported Intel Mac downloading an arm64 release that message named the wrong cause, and
# left a broken bundle installed. Moved up here it costs nothing and answers honestly, and the
# post-install check further down keeps its own job: detecting a copy that went wrong.
#
# The quarantine flag is cleared on the temp copy first, so this probe answers one question
# only ("does this binary run on this supported Mac?") instead of two. The requirements already
# refuse Intel before any download, so an Intel-specific branch here would be unreachable; one
# honest failure message covers every machine that can reach the probe.
xattr -dr com.apple.quarantine "${SRC}" 2>/dev/null || true
if ! "${SRC}/Contents/MacOS/${APP_NAME}" --version >/dev/null 2>&1; then
    die "the ${VERSION} build did not start on this Mac, and nothing was installed. Please open an issue at https://github.com/${REPO}/issues with your macOS version and the release you tried."
fi

# ── Install
DEST_DIR="$(install_dir)"
quit_running
remove_bundle "${DEST_DIR}/${APP_NAME}.app"
cp -R "${SRC}" "${DEST_DIR}/" || die "could not copy into ${DEST_DIR}."

# Releases are not notarized yet, so macOS would refuse to open the download.
# Clearing the quarantine flag is what makes it launchable — it is also exactly
# the step you should read this script to confirm before piping it to a shell.
xattr -dr com.apple.quarantine "${DEST_DIR}/${APP_NAME}.app" 2>/dev/null || true
ok "installed ${DEST_DIR}/${APP_NAME}.app"

# ── Verify what we just installed rather than assuming it works.
#
# The same binary already ran from the temp directory a few lines up, so an architecture
# mismatch is ruled out by the time we get here: what is left is the copy and the quarantine
# flag, which is exactly what this message may now blame.
if ! "${DEST_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" --version >/dev/null 2>&1; then
    die "the copy in ${DEST_DIR} does not run, though the downloaded one did. Try: xattr -cr ${DEST_DIR}/${APP_NAME}.app"
fi

open "${DEST_DIR}/${APP_NAME}.app"

cat <<EOF

$(ok "${APP_NAME} ${VERSION} is running — look for the icon in the menu bar.")

  It asks for no system permissions: no camera, no microphone access, no
  accessibility, no network. Nothing leaves this Mac.

  Work for 30 minutes of real activity and the first break arrives on its own.
  Every number the app uses shows the study it comes from, while it interrupts.

  If anything misbehaves:
    ${DEST_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME} --doctor

EOF
