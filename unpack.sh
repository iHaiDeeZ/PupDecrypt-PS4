#!/bin/bash
# Unpacks the decrypted update parts (PS4UPDATE*.PUP.dec) with pup_unpack.
# usage: bash unpack.sh <folder with the .dec files> <output folder>
#   e.g. bash unpack.sh /f ~/fw-unpacked
set -e
IN="${1:?folder with the .dec files}"
OUT="${2:?output folder}"
TOOL="$(cd "$(dirname "$0")" && pwd)/out/pup_unpack/pup_unpack.exe"
[ -x "$TOOL" ] || { echo "Build pup_unpack first: bash build-unpack.sh"; exit 1; }
mkdir -p "$OUT"
for f in "$IN"/PS4UPDATE*.PUP.dec; do
  name=$(basename "$f" .PUP.dec)
  echo "== $name"
  "$TOOL" "$f" "$OUT/$name"
done
echo "Unpacked into $OUT"
