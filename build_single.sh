#!/bin/bash

cd "$(realpath "$(dirname "$0")")"

proccount=1
if [[ "x$(uname)" == "xDarwin" ]];
then
    proccount=$(sysctl -n hw.physicalcpu)
elif [[ "x$(uname)" == "xLinux" ]];
then
    proccount=$(nproc)
fi

function verbose_copy() {
    echo "==> cp $1 $2"
    cp "$1" "$2"
}

set -e

repo="$1"
if [[ "x$repo" == "x" ]];
then
    echo "Usage: $0 monero/wownero/zano $(gcc -dumpmachine) -j$proccount"
    exit 1
fi

if [[ "x$repo" != "xwownero" && "x$repo" != "xmonero" && "x$repo" != "xzano" ]];
then
    echo "Usage: $0 monero/wownero/zano $(gcc -dumpmachine) -j$proccount"
    echo "Invalid target given"
    exit 1
fi

# Logical target -> actual source dir / wrapper dir / flavor
SOURCE_DIR="$repo"
API_DIR="${repo}_libwallet2_api_c"
FLAVOR="$repo"

if [[ "$repo" == "monero" ]];
then
    SOURCE_DIR="xcash-labs-core"
    API_DIR="monero_libwallet2_api_c"
    FLAVOR="monero"
fi

if [[ ! -d "$SOURCE_DIR" ]];
then
    echo "no '$SOURCE_DIR' directory found. clone with --recursive or run:"
    echo "$ git submodule update --init --recursive"
    exit 1
fi

if [[ ! -d "$API_DIR" ]];
then
    echo "no '$API_DIR' directory found."
    exit 1
fi

HOST_ABI="$2"
if [[ "x$HOST_ABI" == "x" ]];
then
    echo "Usage: $0 monero/wownero/zano $(gcc -dumpmachine) -j$proccount"
    exit 1
fi

NPROC="$3"
if [[ "x$NPROC" == "x" ]];
then
    echo "Usage: $0 monero/wownero/zano $(gcc -dumpmachine) -j$proccount"
    exit 1
fi

cd "$(dirname "$0")"
WDIR=$PWD

pushd contrib/depends
    if [[ -f "$HOST_ABI/share/toolchain.cmake" ]];
    then
        echo "Not building depends, toolchain already exists for $HOST_ABI"
    else
        echo "Building depends for $HOST_ABI"
        rm -rf "$HOST_ABI" "work/build/$HOST_ABI" "built/$HOST_ABI" || true
        env -u MAKEFLAGS PATH="$PATH" CC=gcc CXX=g++ make -j1 HOST="$HOST_ABI" DEPENDS_UNTRUSTED_FAST_BUILDS="$DEPENDS_UNTRUSTED_FAST_BUILDS"
    fi
popd

buildType=Debug

EXTRA_CMAKE_FLAGS=""
if [[ "$repo" == "zano" ]];
then
   EXTRA_CMAKE_FLAGS="-DCAKEWALLET=ON"
fi

pushd "$API_DIR"
    rm -rf "build/${HOST_ABI}" || true
    mkdir -p "build/${HOST_ABI}"

    pushd "build/${HOST_ABI}"
        cmake \
            -DCMAKE_TOOLCHAIN_FILE="$PWD/../../../contrib/depends/${HOST_ABI}/share/toolchain.cmake" \
            $EXTRA_CMAKE_FLAGS \
            -DUSE_DEVICE_TREZOR=OFF \
            -DMONERO_FLAVOR="$FLAVOR" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DHOST_ABI="${HOST_ABI}" \
            ../..
        make "$NPROC"
    popd
popd

mkdir -p "release/$repo" 2>/dev/null || true
pushd "release/$repo"
    APPENDIX=""
    if [[ "${HOST_ABI}" == "x86_64-w64-mingw32" || "${HOST_ABI}" == "i686-w64-mingw32" ]];
    then
        echo "TODO: check if it's still needed"
        APPENDIX="dll"
        # cp ../../$repo/build/${HOST_ABI}/external/polyseed/libpolyseed.${APPENDIX} ${HOST_ABI}_libpolyseed.${APPENDIX}
        # rm ${HOST_ABI}_libpolyseed.${APPENDIX}.xz || true
        # xz -e ${HOST_ABI}_libpolyseed.${APPENDIX}
    elif [[ "${HOST_ABI}" == "x86_64-apple-darwin11" || "${HOST_ABI}" == "aarch64-apple-darwin11" || "${HOST_ABI}" == "host-apple-darwin" || "${HOST_ABI}" == "x86_64-host-apple-darwin" || "${HOST_ABI}" == "aarch64-apple-darwin" || "${HOST_ABI}" == "x86_64-apple-darwin" || "${HOST_ABI}" == "host-apple-ios" || "${HOST_ABI}" == "aarch64-apple-ios" || "${HOST_ABI}" == "aarch64-apple-iossimulator" ]];
    then
        APPENDIX="dylib"
    else
        APPENDIX="so"
    fi

    xz -ek "../../${API_DIR}/build/${HOST_ABI}/libwallet2_api_c.${APPENDIX}"
    mv "../../${API_DIR}/build/${HOST_ABI}/libwallet2_api_c.${APPENDIX}.xz" "${HOST_ABI}_libwallet2_api_c.${APPENDIX}.xz"

    # Extra libraries
    if [[ "$HOST_ABI" == "x86_64-w64-mingw32" || "$HOST_ABI" == "i686-w64-mingw32" ]];
    then
        cp "/usr/${HOST_ABI}/lib/libwinpthread-1.dll" "${HOST_ABI}_libwinpthread-1.dll"
        rm -f "${HOST_ABI}_libwinpthread-1.dll.xz" || true
        xz -ek "${HOST_ABI}_libwinpthread-1.dll"

        cp /usr/lib/gcc/${HOST_ABI}/*-posix/libssp-0.dll "${HOST_ABI}_libssp-0.dll"
        rm -f "${HOST_ABI}_libssp-0.dll.xz" || true
        xz -ek "${HOST_ABI}_libssp-0.dll"
    fi
popd
