#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export DESKTOP=DUMMY
export MAIN_BIN=distrobox

# the distrobox commands are shell scripts, and tracing them follows whatever
# host tool they exec (curl, sudo, the shell itself), which drags those tools'
# libraries into the image. Nothing we ship dlopens anything, so only the ELF
# helpers are traced
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

# catatonit runs as pid 1 inside the container, which cannot read the mount, so
# podman needs the binary itself rather than the sharun hardlink
rm -f AppDir/bin/catatonit
mv AppDir/shared/bin/catatonit AppDir/bin/catatonit
if ! file AppDir/bin/catatonit | grep -q 'statically linked'; then
	echo "catatonit must be static, a container cannot read the mount"
	exit 1
fi

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
