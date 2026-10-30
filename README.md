<div align="center">

[![Release](https://img.shields.io/github/v/release/iHaiDeeZ/PupDecrypt-PS4?style=for-the-badge&color=2b6cb0)](https://github.com/iHaiDeeZ/PupDecrypt-PS4/releases/latest)
![PS4 payload](https://img.shields.io/badge/PS4-payload-003791?style=for-the-badge&logo=playstation&logoColor=white)
![Firmware](https://img.shields.io/badge/offsets-up%20to%2014.00-6b46c1?style=for-the-badge)
[![License](https://img.shields.io/badge/license-GPL--3.0-2f855a?style=for-the-badge)](LICENSE)

### Decrypt PS4 firmware update files on your own console, built on Windows

**[⬇ Get the latest release](https://github.com/iHaiDeeZ/PupDecrypt-PS4/releases/latest)** · [Getting started](#getting-started) · [Building](#building) · [FAQ](#faq) · [Credits](#thanks)

</div>

---

## Overview

A payload that asks your PS4 to decrypt a system software update file (`PS4UPDATE.PUP`) and writes the decrypted parts to a USB stick, plus an unpacker that turns those parts into the firmware's filesystem images. It is meant for firmware research on hardware you own.

The payload is [andy-man/ps4-pup-decrypt](https://github.com/andy-man/ps4-pup-decrypt) (from idc's original) built against [Scene-Collective/ps4-payload-sdk](https://github.com/Scene-Collective/ps4-payload-sdk), which has kernel offsets up to firmware 14.00. This repository adds what it takes to build both tools on Windows with MSYS2's clang and .NET.

No keys and no firmware are included. The console decrypts the update with its own hardware.

## Highlights

**Tested**
- Decrypted the 14.00 recovery update (1.08 GB, 4 parts) on a 13.52 console with GoldHEN in about 17.5 minutes; each decrypted part matches the size in the update's header.

**Builds on Windows**
- MSYS2 clang + lld target FreeBSD ELF directly; no Linux or WSL needed.
- A build-time check rejects any direct call into data, the bug that made the first clang build crash at launch (details in [`build-payload.sh`](build-payload.sh)).
- Upstream sources are pinned to exact commits; every change is a small patch in [`patches/`](patches).

**Unpacker on modern .NET**
- idc's [pup_unpack](https://github.com/idc/ps4-pup_unpack) builds for .NET 10, with reads that no longer abort when a stream returns less than asked.

## Getting started

**You need:** a jailbroken PS4 running GoldHEN (BinLoader enabled), a USB stick formatted exFAT or FAT32 with about twice the update's size free, and the update file you want to decrypt.

1. Copy the update to the root of the stick and rename it to **`safe.PS4UPDATE.PUP`**.
2. Plug the stick into the PS4.
3. Send `ps4-pup-decrypt.bin` from the [latest release](https://github.com/iHaiDeeZ/PupDecrypt-PS4/releases/latest) to GoldHEN's BinLoader (port 9090), for example:
   ```bash
   nc -q 1 <console ip> 9090 < ps4-pup-decrypt.bin
   ```
4. Wait for the **"Finished PS4 PUP Decrypter"** notification. The stick then holds `PS4UPDATE1.PUP.dec` … `PS4UPDATE4.PUP.dec` (two parts for a normal update, four for a recovery one).
5. Unpack them on the PC:
   ```bash
   bash build-unpack.sh
   bash unpack.sh <folder with the .dec files> <output folder>
   ```

> **Note:** the console only decrypts retail updates for its own model line at or above its installed firmware. A retail console cannot decrypt test or debug updates.

## Building

From an MSYS2 shell:

```bash
pacman -S --needed git make mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-lld mingw-w64-ucrt-x86_64-llvm-tools
bash build-payload.sh   # -> out/ps4-pup-decrypt.bin
bash build-unpack.sh    # -> out/pup_unpack/ (needs the .NET SDK)
```

Sources are cloned into `~/pup-decrypt-build` (set `PUPDEC_WORK` to change it).

| Patch | Why |
|---|---|
| `sdk-clang.patch` | Intel-syntax forms clang's assembler rejects; zero big locals with `rep stosb`, because clang turns `= {}` into a call to the symbol `memset`, which in this SDK is libc's function pointer in `.bss` |
| `payload-clang.patch` | Prototype for `GetElapsed` (returns `uint8_t`; without it the caller reads an `int`) |
| `pup_unpack.patch` | Read loops that keep going until the buffer is full |

## FAQ

**The payload starts, then nothing happens.**
Check GoldHEN's kernel log (TCP port 3232). A `GoldHENLoader` fatal signal means the payload crashed. GoldHEN loads BIN payloads at `0x40000`, so subtract that from the reported `rip` to find the offset in the bin.

**"Failed to open /dev/pup_update0".**
The payload could not raise its privileges. Load GoldHEN first and check that your firmware is one the SDK has offsets for.

**Why do I see so many notifications?**
The payload reports every block it decrypts. It is noisy but harmless; they keep appearing for a while after it finishes.

**Are the programs inside the update readable now?**
Not yet. Decrypting the update removes its outer layer; the programs inside (`.sprx`, `.self`, `.elf`) are still encrypted SELF files.

## Thanks

- **[idc](https://github.com/idc)** for pup_decrypt and pup_unpack
- **[andy-man](https://github.com/andy-man/ps4-pup-decrypt)** for the updated payload
- **[Scene-Collective](https://github.com/Scene-Collective/ps4-payload-sdk)** and everyone in the SDK's chain (CTurt, IDC, xvortex, stooged) for the payload SDK
- **[GoldHEN](https://github.com/GoldHEN)** for the BinLoader and kernel log

## License and disclaimer

GPL-3.0, like the payload it builds ([LICENSE](LICENSE)). pup_unpack's changes are under its original MIT license.

This project is not affiliated with or endorsed by Sony Interactive Entertainment. PlayStation and PS4 are trademarks of their owners. Use it only on hardware you own, and do not distribute firmware.
