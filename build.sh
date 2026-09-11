#!/usr/bin/env bash
#
# 从 SwiftPM 软件包构建 Mac Duo.app。
#
#   ./build.sh              构建并签名
#   ./build.sh --run        构建、签名并重新启动应用
#   ./build.sh --universal  同时构建 Apple 芯片与 Intel 版本
#
# 默认使用临时签名。重新构建后，macOS 可能要求再次授予屏幕录制权限。
# 设置 SIGN_IDENTITY 可使用自己的签名身份。

set -euo pipefail
cd "$(dirname "$0")"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP_NAME="Mac Duo"
BUNDLE="build/${APP_NAME}.app"

BUILD_ARGS=(-c release)
RUN_APP=false
for argument in "$@"; do
  case "$argument" in
    --universal) BUILD_ARGS+=(--arch arm64 --arch x86_64) ;;
    --run) RUN_APP=true ;;
    *) echo "未知参数：$argument" >&2; exit 1 ;;
  esac
done

swift build "${BUILD_ARGS[@]}" --product MacDuo
swift build "${BUILD_ARGS[@]}" --product lidprobe

BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BINARY="$BIN_PATH/MacDuo"
PROBE="$BIN_PATH/lidprobe"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/MacDuo"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp LICENSE NOTICE "$BUNDLE/Contents/Resources/"
cp Resources/Logo.png Resources/MenuBarIcon.png "$BUNDLE/Contents/Resources/"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
fi
cp "$PROBE" build/lidprobe

TIMESTAMP=--timestamp
if [[ "$SIGN_IDENTITY" == - ]]; then
  TIMESTAMP=--timestamp=none
fi
codesign --force --options runtime "$TIMESTAMP" \
  --sign "$SIGN_IDENTITY" "$BUNDLE"
codesign --verify --strict --verbose=1 "$BUNDLE"

echo "构建完成：${BUNDLE}"
codesign -dv "$BUNDLE" 2>&1 | grep -E "Identifier|TeamIdentifier|Signature" || true

if "$RUN_APP"; then
  pkill -x MacDuo 2>/dev/null || true
  sleep 0.5
  open "$BUNDLE"
  echo "应用已启动"
fi
