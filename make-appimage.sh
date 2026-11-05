#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q distrobox | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export DESKTOP=DUMMY
export MAIN_BIN=distrobox

# Deploy dependencies
quick-sharun \
	/usr/bin/distrobox* \
	/usr/bin/conmon     \
	/usr/bin/compel     \
	/usr/bin/criu       \
	/usr/bin/crun       \
	/usr/bin/podman*    \
	/usr/lib/podman

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
