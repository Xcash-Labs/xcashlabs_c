# wallet2_api.h (but this time C compatible)

> Wrapper around wallet2_api.h that can be called using a C API. The `monero` build option uses the `xcash-labs-core` submodule for this implemtation.

## Building

Quick start:

```bash
rm -rf xcash-labs-core wownero zano release
git submodule update --init --recursive --force
for coin in xcash-labs-core wownero zano; do ./apply_patches.sh "$coin"; done
```