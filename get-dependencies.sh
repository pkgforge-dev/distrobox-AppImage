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
	curl        \
	go          \
	go-md2man   \
	gpgme       \
	libtool     \
	mbedtls     \
	passt       \
	podman      \
	shadow      \
	sqlite      \
	systemd

#echo "Installing debloated packages..."
#echo "---------------------------------------------------------------"
#get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here
echo "Building distrobox..."
echo "---------------------------------------------------------------"
git clone https://github.com/89luca89/distrobox ./distrobox-src && (
	cd ./distrobox-src

	git fetch --tags origin
	DISTROBOX_TAG=$(git tag --sort=-v:refname | grep -vi 'rc\|alpha' | head -1)
	git checkout "$DISTROBOX_TAG"
	echo "$DISTROBOX_TAG" > ~/version

	git apply -p1 ../patches/0001-distrobox-path.patch
	./install --prefix /usr
)

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
	./configure --disable-static --disable-criu --enable-embedded-blake3
	make -j"$(nproc)"
	cp -f ./crun /usr/bin/crun
	chmod +x /usr/bin/crun
)

echo "Building curl..."
echo "---------------------------------------------------------------"
git clone https://github.com/curl/curl ./curl-src && (
	cd ./curl-src

	git fetch --tags origin
	CURL_TAG=$(git tag --sort=-v:refname | grep -vi 'rc\|alpha\|tiny-curl' | head -1)
	git checkout "$CURL_TAG"

	# mbedtls is linked in statically so the image does not have to carry
	# openssl, while glibc stays dynamic like everything else here.  Only the
	# .a files go into the prefix, so the linker cannot pick the shared ones
	mkdir -p ../mbedtls-static/lib
	ln -sf /usr/lib/libmbedtls.a /usr/lib/libmbedx509.a \
		/usr/lib/libmbedcrypto.a ../mbedtls-static/lib/

	autoreconf -fi
	./configure --disable-shared --enable-static \
		--with-mbedtls="$PWD/../mbedtls-static" \
		--with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
		--without-zlib --without-brotli --without-zstd --without-libpsl \
		--without-libidn2 --without-libssh2 --without-nghttp2 \
		--disable-ldap --disable-ldaps --disable-ftp --disable-file \
		--disable-rtsp --disable-dict --disable-telnet --disable-tftp \
		--disable-pop3 --disable-imap --disable-smtp --disable-gopher \
		--disable-mqtt --disable-ntlm --disable-manual --disable-docs
	make -j"$(nproc)"
	cp -f ./src/curl /usr/bin/curl
	chmod +x /usr/bin/curl
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
