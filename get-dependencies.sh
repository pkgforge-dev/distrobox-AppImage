#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	autoconf    \
	automake    \
	btrfs-progs \
	crun        \
	distrobox   \
	go          \
	go-md2man   \
	gpgme       \
	libtool     \
	podman      \
	python      \
	shadow      \
	sqlite      \
	systemd

#echo "Installing debloated packages..."
#echo "---------------------------------------------------------------"
#get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here
echo "Patching distrobox..."
echo "---------------------------------------------------------------"
patch -d / -p1 --forward --no-backup-if-mismatch < ./patches/0001-distrobox-path.patch

echo "Building crun..."
echo "---------------------------------------------------------------"
git clone https://github.com/containers/crun ./crun && (
	cd ./crun

	# crun still ships v0.3-style tags, which sort above 1.30.1 with v:refname
	git fetch --tags origin
	CRUN_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.' | head -1)
	git checkout "$CRUN_TAG"
	git submodule update --init --recursive

	git apply -p1 ../patches/0002-crun-bind-source-fallback.patch
	./autogen.sh
	./configure --disable-static --disable-criu
	make -j"$(nproc)"
	cp -f ./crun /usr/bin/crun
	chmod +x /usr/bin/crun
)

echo "Building podman..."
echo "---------------------------------------------------------------"
git clone https://github.com/containers/podman ./podman-src && (
	cd ./podman-src

	git fetch --tags origin
	PODMAN_TAG=$(git tag --sort=-v:refname | grep -vi 'rc\|alpha' | head -1)
	git checkout "$PODMAN_TAG"

	git apply -p1 ../patches/0003-podman-bind-source-fallback.patch

	# the flags of the distribution build, and the tags that matter for it: a
	# missing one is silent, and seccomp, sqlite or systemd cannot be dropped
	make GOFLAGS="-buildmode=pie -mod=vendor" \
		EXTRA_LDFLAGS="-linkmode=external" \
		PREFIX=/usr podman
	cp -f ./bin/podman /usr/bin/podman
	chmod +x /usr/bin/podman
)
