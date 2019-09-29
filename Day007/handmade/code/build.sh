echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit
              -framework IOKit"

mkdir ../../build
pushd ../../build
clang -g $OSX_LD_FLAGS -o handmade ../handmade/code/osx_main.mm
popd
