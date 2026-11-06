#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export DESKTOP=DUMMY
export MAIN_BIN=distrobox
export STRACE_BINARY="podman crun conmon catatonit netavark aardvark-dns rootlessport"

# Deploy dependencies
quick-sharun \
	/usr/bin/distrobox*           \
	/usr/bin/catatonit            \
	/usr/bin/conmon               \
	/usr/bin/crun                 \
	/usr/bin/curl                 \
	/usr/bin/passt                \
	/usr/bin/pasta                \
	/usr/bin/podman               \
	/usr/lib/podman/aardvark-dns  \
	/usr/lib/podman/netavark      \
	/usr/lib/podman/rootlessport

# catatonit runs as pid 1 inside the container, which cannot read the 
# appimage mount point, so podman needs the binary itself
# It is static already so this is not a problem
rm -f ./AppDir/bin/catatonit
mv ./AppDir/shared/bin/catatonit ./AppDir/bin/catatonit
if ! file AppDir/bin/catatonit | grep -q 'statically linked'; then
	>&2 echo "catatonit must be a static binary!"
	exit 1
fi

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
