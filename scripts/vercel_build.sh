#!/usr/bin/env bash
set -euo pipefail

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_DIR="${FLUTTER_DIR:-$PWD/.vercel/flutter}"
FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"
BASE_HREF="${VERCEL_BASE_HREF:-/}"

if [[ "$BASE_HREF" != /* ]]; then
  BASE_HREF="/$BASE_HREF"
fi

if [[ "$BASE_HREF" != */ ]]; then
  BASE_HREF="$BASE_HREF/"
fi

if [[ ! -x "$FLUTTER_BIN" ]]; then
  rm -rf "$FLUTTER_DIR"
  git clone --depth 1 --branch "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version
flutter config --enable-web
flutter pub get
flutter build web   --release   --base-href "$BASE_HREF"   --dart-define=FLUTTER_WEB_AUTO_DETECT=false
