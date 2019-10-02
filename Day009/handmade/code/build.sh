echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit
              -framework IOKit"

mkdir ../../build
pushd ../../build
rm -rf handmade.app
mkdir -p handmade.app
clang -g $OSX_LD_FLAGS -o handmade ../handmade/code/osx_main.mm
cp handmade handmade.app/handmade
cp "../handmade/resources/Info.plist" handmade.app/Info.plist
popd
