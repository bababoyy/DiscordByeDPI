#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if ! command -v xcrun >/dev/null; then
  echo 'The iOS build needs Xcode on macOS. Use the included GitHub Actions workflow.' >&2
  exit 1
fi
port="${DBD_PROXY_PORT:-10800}"
if ! [[ "$port" =~ ^[0-9]{1,5}$ ]] || (( 10#$port < 1 || 10#$port > 65535 )); then
  echo 'DBD_PROXY_PORT must be 1..65535.' >&2
  exit 1
fi
port=$((10#$port))
mkdir -p dist
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -arch arm64 -c \
  -isysroot "$sdk" -miphoneos-version-min=15.0 \
  -O2 -Wall -Wextra -Werror local_probe.c -o dist/local_probe.o
xcrun --sdk iphoneos clang -arch arm64 -dynamiclib \
  -isysroot "$sdk" -miphoneos-version-min=15.0 -fobjc-arc -fblocks \
  -O2 -Wall -Wextra -Werror -DDBD_PROXY_PORT="$port" \
  -framework Foundation \
  -Wl,-install_name,@rpath/DiscordByeDPI.dylib \
  DiscordByeDPI.m dist/local_probe.o -o dist/DiscordByeDPI.dylib
rm dist/local_probe.o
codesign --force --sign - dist/DiscordByeDPI.dylib
codesign --verify --verbose dist/DiscordByeDPI.dylib
xcrun lipo -info dist/DiscordByeDPI.dylib
xcrun otool -L dist/DiscordByeDPI.dylib
cp INSTALL.md dist/INSTALL.md
(cd dist && shasum -a 256 DiscordByeDPI.dylib > SHA256SUMS)
