#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q distrobox | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/128x128/apps/terminal-distrobox-icon.png
export DESKTOP=DUMMY
export MAIN_BIN=distrobox
export DEPLOY_SYS_PYTHON=1
export ANYLINUX_LIB=1
export PATH_MAPPING='/usr/bin/distrobox*:${SHARUN_DIR}/bin/distrobox*'

# Deploy dependencies
quick-sharun \
	/usr/bin/distrobox* \
	/usr/bin/conmon     \
	/usr/bin/crun       \
	/usr/bin/krun       \
	/usr/bin/compel     \
	/usr/bin/crit       \
	/usr/bin/criu       \
	/usr/bin/criu-ns    \
	/usr/bin/podman*    \
	/usr/lib/podman

# crun gets broken when used with sharun
# Failed to check ELF class: /memfd:crun_cloned:/proc/self/shared/bin/exe (deleted): No such file or directory (os error 2)
# we will have to do some hacks to get it to work
kek=.$(tr -dc 'A-Za-z0-9_=-' < /dev/urandom | head -c 10)
rm -f ./AppDir/bin/crun                 ./AppDir/shared/bin/crun
cp -v /usr/bin/crun                     ./AppDir/bin/crun.wrapped
patchelf --set-interpreter /tmp/"$kek"  ./AppDir/bin/crun.wrapped
cat <<EOF > ./AppDir/bin/crun
#!/bin/sh
cp -f "\$APPDIR"/shared/lib/ld-linux*.so* /tmp/"$kek"
export LD_LIBRARY_PATH="\$APPDIR"/shared/lib
exec "\$APPDIR"/sharun crun.wrapped "\$@"
EOF
chmod +x ./AppDir/bin/crun*

# Turn AppDir into AppImage
quick-sharun --make-appimage
