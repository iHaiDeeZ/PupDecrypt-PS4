#!/bin/bash
# Builds out/ps4-pup-decrypt.bin: andy-man/ps4-pup-decrypt against
# Scene-Collective/ps4-payload-sdk (which has the 14.00 offsets), with MSYS2's clang + lld.
#
# Run from any MSYS2 shell:   bash build-payload.sh
# Needs: pacman -S git make mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-lld mingw-w64-ucrt-x86_64-llvm-tools
# Sources are cloned into $PUPDEC_WORK (default ~/pup-decrypt-build).
#
# patches/sdk-clang.patch:
#  - clang's assembler rejects 'movq reg, imm' and '%%cr0' in Intel syntax (GNU as allows them)
#  - printf_debug/printf_notification zero their buffers with 'rep stosb': clang compiles
#    '= {}' on big locals into 'call memset', and memset here is libc's function pointer
#    in .bss, so the payload jumped into data and crashed right after launch
# patches/payload-clang.patch:
#  - GetElapsed returns uint8_t; without a prototype the caller would read it as int
set -e
export PATH=/ucrt64/bin:$PATH
REPO="$(cd "$(dirname "$0")" && pwd)"
W="${PUPDEC_WORK:-$HOME/pup-decrypt-build}"
SDK_COMMIT=b7326416c23ce14639e9180a24093bdc5eedb579      # "Add 14.00 support"
PAYLOAD_COMMIT=74c64c0e8726a7cd6c1de6a9d0b1b751f8fe9b97

checkout() { # url dir commit
  [ -d "$W/$2" ] || git clone -q "$1" "$W/$2"
  git -C "$W/$2" checkout -q "$3"
}
apply() { # dir patch: apply once, accept if already applied
  git -C "$W/$1" apply --check "$2" 2>/dev/null && git -C "$W/$1" apply "$2" ||
    git -C "$W/$1" apply --reverse --check "$2"
}

mkdir -p "$W" "$REPO/out"
checkout https://github.com/Scene-Collective/ps4-payload-sdk ps4-payload-sdk $SDK_COMMIT
checkout https://github.com/andy-man/ps4-pup-decrypt ps4-pup-decrypt $PAYLOAD_COMMIT
apply ps4-payload-sdk "$REPO/patches/sdk-clang.patch"
apply ps4-pup-decrypt "$REPO/patches/payload-clang.patch"

# MinGW gcc only makes PE files; clang targets FreeBSD ELF, and ld.lld needs
# -m elf_x86_64 or MSYS2's build starts it as the Windows (PE) linker.
CLANG="clang --target=x86_64-pc-freebsd --ld-path=/ucrt64/bin/ld.lld.exe -Wl,-m,elf_x86_64"

cd "$W/ps4-payload-sdk/libPS4"
rm -rf build libPS4.a
make CC="$CLANG" AR=llvm-ar

# The payload only uses static_assert from <assert.h>; there is no host libc here.
mkdir -p "$W/compat"
printf '#ifndef static_assert\n#define static_assert _Static_assert\n#endif\n' > "$W/compat/assert.h"

cd "$W/ps4-pup-decrypt"
make clean
PS4SDK="$W/ps4-payload-sdk" make CC="$CLANG -I$W/compat" OBJCOPY=llvm-objcopy

# Link once more to an ELF and refuse any direct call/jmp into .rodata/.data/.bss
# (libc functions are pointers there; a direct call means clang emitted a libcall).
PS4SDK="$W/ps4-payload-sdk"
$CLANG -nostdlib -nostartfiles $PS4SDK/libPS4/crt0.s build/*.o -o build/check.elf -L$PS4SDK/libPS4 \
  -Xlinker -T $PS4SDK/libPS4/linker.x -Wl,--build-id=none -Wl,--gc-sections -lPS4 2>/dev/null
DATA=$(llvm-readelf -S build/check.elf | awk '{for (i = 1; i < NF; i++) if ($i == ".rodata") print "0x"$(i+2)}')
[ -n "$DATA" ] || { echo "No .rodata in check.elf"; exit 1; }
BAD=$(llvm-objdump -d --no-show-raw-insn build/check.elf |
  awk -v d=$((DATA)) '/(call|jmp)[a-z]*[ \t]+0x[0-9a-f]+ </{ if (match($0,/0x[0-9a-f]+ </) && strtonum(substr($0,RSTART,RLENGTH-2))>=d) print }')
if [ -n "$BAD" ]; then echo "Direct calls into data (would crash):"; echo "$BAD"; exit 1; fi

cp ps4-pup-decrypt.bin "$REPO/out/"
echo "Built $REPO/out/ps4-pup-decrypt.bin"
