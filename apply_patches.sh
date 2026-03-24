#!/bin/bash

cd "$(realpath "$(dirname "$0")")"

repo="$1"

if [[ -z "$repo" ]]; then
    echo "Usage: $0 monero/xcash-labs-core/wownero/zano"
    exit 1
fi

if [[ "$repo" != "monero" && "$repo" != "xcash-labs-core" && "$repo" != "wownero" && "$repo" != "zano" ]]; then
    echo "Usage: $0 monero/xcash-labs-core/wownero/zano"
    echo "Invalid target given"
    exit 1
fi

# Map logical name -> actual source dir
SOURCE_DIR="$repo"
PATCH_DIR="$repo"

if [[ "$repo" == "monero" ]]; then
    SOURCE_DIR="xcash-labs-core"

    # Prefer xcash-labs-core patches if present, otherwise fall back to monero patches
    if [[ -d "patches/xcash-labs-core" ]]; then
        PATCH_DIR="xcash-labs-core"
    else
        PATCH_DIR="monero"
    fi
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "no '$SOURCE_DIR' directory found. clone with --recursive or run:"
    echo "$ git submodule update --init --recursive --force"
    exit 1
fi

if [[ ! -d "patches/$PATCH_DIR" ]]; then
    echo "No patches for '$PATCH_DIR'; skipping."
    exit 0
fi

if [[ -f "$SOURCE_DIR/.patch-applied" ]]; then
    echo "$SOURCE_DIR/.patch-applied file exists. Manual investigation recommended."
    exit 0
fi

set -e
cd "$SOURCE_DIR"

# Apply repo patches
git am -3 --whitespace=fix --reject ../patches/"$PATCH_DIR"/*.patch

# Repo-specific submodule URL fixes
if [[ "$SOURCE_DIR" == "wownero" ]]; then
    pushd external/randomwow
        git remote set-url origin https://github.com/mrcyjanek/randomwow.git
    popd
fi

if [[ "$SOURCE_DIR" == "zano" ]]; then
    pushd contrib/tor-connect
        git remote set-url origin https://github.com/mrcyjanek/tor-connect.git
    popd
fi

git submodule init
git submodule update --init --recursive --force

POST_PATCH_DIR="${PATCH_DIR}-post"
if [[ -d "../patches/$POST_PATCH_DIR" ]]; then
    if [[ -d external/polyseed ]]; then
        for patch in ../patches/"$POST_PATCH_DIR"/*.patch; do
            [[ -f "$patch" ]] || continue
            echo "Applying post patch $(basename "$patch") in external/polyseed"
            (
                cd external/polyseed
                git am -3 --whitespace=fix --reject "../../../patches/$POST_PATCH_DIR/$(basename "$patch")"
            )
        done
    else
        echo "Post patch directory exists, but external/polyseed was not found"
        exit 1
    fi
fi

# Only operate on files tracked by THIS repo, not nested submodule contents
while IFS= read -r file; do
    [[ -f "$file" ]] || continue

    if ! grep -q "\.note\.GNU-stack" "$file"; then
        echo "Adding conditional .note.GNU-stack section to: $file"
        {
            echo ""
            echo "#ifdef __linux__"
            echo ".section .note.GNU-stack,\"\",@progbits"
            echo "#endif"
        } >> "$file"
        git add "$file"
    fi
done < <(git ls-files '*.S' '*.s')

# Commit only if something was actually staged
if ! git diff --cached --quiet; then
    git commit -m "Add .note.GNU-stack section to assembly files"
else
    echo "No assembly files needed .note.GNU-stack updates"
fi

git am -3 <<'EOF'
From e56dd6cd0fb1a5e55d3cb08691edf24b26d65299 Mon Sep 17 00:00:00 2001
From: Czarek Nakamoto <cyjan@mrcyjanek.net>
Date: Fri, 20 Dec 2024 09:18:08 +0100
Subject: [PATCH] add .patch-applied

---
 .patch-applied | 0
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 .patch-applied

diff --git a/.patch-applied b/.patch-applied
new file mode 100644
index 000000000..e69de29bb
--
2.39.5 (Apple Git-154)
EOF

echo "you are good to go!"
