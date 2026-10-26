#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/lambda-src"
BUILD="$ROOT/build"
ZIP="$ROOT/lambda.zip"

rm -rf "$BUILD"
mkdir -p "$BUILD"

python3 -m pip install --quiet --upgrade --target "$BUILD" -r "$SRC/requirements.txt"
cp "$SRC/handler.py" "$BUILD/"
find "$BUILD" -type d -name "__pycache__" -prune -exec rm -rf {} +

rm -f "$ZIP"
(cd "$BUILD" && zip -qr "$ZIP" .)

echo "Built $ZIP"
