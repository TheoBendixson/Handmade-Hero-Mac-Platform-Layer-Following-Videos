echo Building Handmade Hero

INCLUDED_FRAMEWORKS="-framework AppKit
                     -framework IOKit
                     -framework AudioToolbox"

RESOURCES_PATH="../handmade/resources"

BUNDLE_RESOURCES_PATH="handmade.app/Contents/Resources"

mkdir ../../build
pushd ../../build
rm -rf handmade.app
mkdir -p $BUNDLE_RESOURCES_PATH
clang -g "-DHANDMADE_INTERNAL=1" $INCLUDED_FRAMEWORKS -o handmade ../handmade/code/osx_main.mm
cp handmade handmade.app/handmade
cp "${RESOURCES_PATH}/Info.plist" handmade.app/Info.plist
cp "${RESOURCES_PATH}/test_background.bmp" $BUNDLE_RESOURCES_PATH
popd
