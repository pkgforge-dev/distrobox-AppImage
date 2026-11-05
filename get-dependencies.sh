#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	autoconf   \
	automake   \
	crun       \
	distrobox  \
	go-md2man  \
	libtool    \
	podman     \
	python

echo "Patching distrobox..."
echo "---------------------------------------------------------------"
patch -d / -p1 --forward --no-backup-if-mismatch < ./patches/0001-distrobox-path.patch

echo "Building crun..."
echo "---------------------------------------------------------------"
git clone https://github.com/containers/crun ./crun

# crun still ships v0.3-style tags, which sort above 1.30.1 with v:refname
git -C ./crun fetch --tags origin
CRUN_TAG=$(git -C ./crun tag --sort=-v:refname | grep -E '^[0-9]+\.' | head -1)
git -C ./crun checkout "$CRUN_TAG"
git -C ./crun submodule update --init --recursive

patch -d ./crun -p1 --forward --no-backup-if-mismatch < ./patches/0002-crun-bind-source-fallback.patch
cd ./crun
./autogen.sh
./configure --disable-static --disable-criu
make -j"$(nproc)"

cp -f ./crun /usr/bin/crun
chmod +x /usr/bin/crun

#echo "Installing debloated packages..."
#echo "---------------------------------------------------------------"
#get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here

# if you also have to make nightly releases check for DEVEL_RELEASE = 1
#
# if [ "${DEVEL_RELEASE-}" = 1 ]; then
# 	nightly build steps
# else
# 	regular build steps
# fi

# Note that when building manually, you want to output the version of the
# application to a ~/version file and remove VERSION from make-appimage.sh
