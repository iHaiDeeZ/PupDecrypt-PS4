#!/bin/bash
# Builds out/pup_unpack/pup_unpack.exe: idc/ps4-pup_unpack on modern .NET.
#
# Run from Git Bash or MSYS2:   bash build-unpack.sh
# Needs: git and the .NET SDK (8 or newer; the project targets net10.0).
#
# patches/pup_unpack.patch: reads loop until the buffer is full. Newer .NET inflater
# streams may return fewer bytes than asked, which made the original abort.
set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
W="${PUPDEC_WORK:-$HOME/pup-decrypt-build}"
UNPACK_COMMIT=a2ea44b7886551bfb103c60f3477f2999a3d1122

mkdir -p "$W"
[ -d "$W/ps4-pup_unpack" ] || git clone -q https://github.com/idc/ps4-pup_unpack "$W/ps4-pup_unpack"
git -C "$W/ps4-pup_unpack" checkout -q $UNPACK_COMMIT
git -C "$W/ps4-pup_unpack" apply --check "$REPO/patches/pup_unpack.patch" 2>/dev/null &&
  git -C "$W/ps4-pup_unpack" apply "$REPO/patches/pup_unpack.patch" ||
  git -C "$W/ps4-pup_unpack" apply --reverse --check "$REPO/patches/pup_unpack.patch"

mkdir -p "$W/ps4-pup_unpack/net"
cp "$REPO/pup_unpack/pup_unpack.csproj" "$W/ps4-pup_unpack/net/"
dotnet build "$W/ps4-pup_unpack/net/pup_unpack.csproj" -c Release -o "$REPO/out/pup_unpack" -nologo -v q
echo "Built $REPO/out/pup_unpack/pup_unpack.exe"
