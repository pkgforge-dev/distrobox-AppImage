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

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
