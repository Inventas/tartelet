#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *)
  echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2
  exit 2
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
BUNDLE_ID="${TARTELET_BUNDLE_ID:-dk.shape.Tartelet.Development}"
DERIVED_DATA="$ROOT_DIR/build/Development"
APP="$DERIVED_DATA/Build/Products/Debug/Tartelet.app"
XCODEGEN_BIN="${XCODEGEN:-xcodegen}"
if ! command -v "$XCODEGEN_BIN" >/dev/null; then
  echo "Install XcodeGen (brew install xcodegen), or set XCODEGEN to its executable path." >&2
  exit 1
fi
"$XCODEGEN_BIN" generate

# Quit only this development app, allowing its VM cleanup to finish.
if [[ "$MODE" != "--build-only" ]] && pgrep -f "$APP/Contents/MacOS/Tartelet" >/dev/null; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit"
  for _ in {1..30}; do
    if ! pgrep -f "$APP/Contents/MacOS/Tartelet" >/dev/null; then break; fi
    sleep 1
  done
  if pgrep -f "$APP/Contents/MacOS/Tartelet" >/dev/null; then
    echo "Tartelet is still cleaning up its VMs. Wait for cleanup before restarting." >&2
    exit 1
  fi
fi

SIGNING=(CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=)
if [[ -n "${TARTELET_DEVELOPMENT_TEAM:-}" ]]; then
  SIGNING=("DEVELOPMENT_TEAM=$TARTELET_DEVELOPMENT_TEAM")
fi
xcodebuild -project Tartelet.xcodeproj -scheme Tartelet -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DERIVED_DATA" \
  "TARTELET_BUNDLE_IDENTIFIER=$BUNDLE_ID" "${SIGNING[@]}" build

case "$MODE" in
  --build-only) ;;
  --debug) lldb -- "$APP/Contents/MacOS/Tartelet" ;;
  --logs|--telemetry)
    open -n "$APP"
    /usr/bin/log stream --info --style compact --predicate 'process == "Tartelet"'
    ;;
  --verify)
    open -n "$APP" --args -startVirtualMachinesOnLaunch NO
    sleep 2
    pgrep -f "$APP/Contents/MacOS/Tartelet" >/dev/null
    ;;
  run) open -n "$APP" ;;
esac
