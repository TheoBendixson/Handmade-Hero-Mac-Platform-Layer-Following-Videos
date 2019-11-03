echo Building Handmade Hero

INCLUDED_FRAMEWORKS="-framework AppKit
                     -framework IOKit
                     -framework AudioToolbox"

mkdir ../../build
pushd ../../build
rm -rf handmade.app
mkdir -p handmade.app
clang -g $INCLUDED_FRAMEWORKS -o handmade ../handmade/code/osx_main.mm
cp handmade handmade.app/handmade
cp "../handmade/resources/Info.plist" handmade.app/Info.plist
popd
