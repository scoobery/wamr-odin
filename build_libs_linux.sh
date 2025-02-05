#!/bin/sh

# Default values
BUILD_INTERP=1
BUILD_AOT=0
BUILD_LIBC_WASI=1
BUILD_PLATFORM=linux

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --interp=*) BUILD_INTERP="${1#*=}";;
    --aot=*) BUILD_AOT="${1#*=}";;
    --libc-wasi=*) BUILD_LIBC_WASI="${1#*=}";;
    --platform=*) BUILD_PLATFORM="${1#*=}";;
    *) echo "Unknown option: $1"; exit 1;;
  esac
  shift
done

cd ./wasm-micro-runtime
rm -rf build
mkdir build
cd ./build

cmake .. -DWAMR_BUILD_INTERP="$BUILD_INTERP" \
         -DWAMR_BUILD_AOT="$BUILD_AOT" \
         -DWAMR_BUILD_LIBC_WASI="$BUILD_LIBC_WASI" \
         -DWAMR_BUILD_PLATFORM="$BUILD_PLATFORM"

make -j$(nproc)

cp ./libvmlib.a ../../lib/linux/libvmlib.a
cd ..
rm -rf build