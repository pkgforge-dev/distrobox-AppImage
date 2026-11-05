#!/bin/sh
# Usage: tests/stale-saved-namespace.sh ./distrobox-*.AppImage
#
# Rootless podman joins the namespace saved by an earlier podman run. This
# creates that namespace with the host's podman, then launches the AppImage
# in a private mount namespace so its mount is not in the saved one, and
# expects `list` to work. Needs the host's podman, sudo without a password,
# unshare and setpriv. It starts and kills processes: run it on a disposable
# machine.
set -u

image=$(readlink -f "${1:?usage: $0 AppImage}")
command -v podman >/dev/null || { echo "SKIP: no host podman"; exit 77; }
sudo -n true || { echo "SKIP: sudo needs a password"; exit 77; }

work=$(mktemp -d)
export XDG_RUNTIME_DIR=$work/run
mkdir -m 700 "$XDG_RUNTIME_DIR"

cleanup() {
	for dir in /proc/[0-9]*; do
		[ -r "$dir"/environ ] || continue
		if tr '\0' '\n' < "$dir"/environ | grep -qx "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"; then
			kill -9 "${dir#/proc/}" 2>/dev/null
		fi
	done
	sleep 1
	rm -rf "$work"
}
trap cleanup EXIT

podman ps -a < /dev/null > /dev/null 2>&1
[ -r "$XDG_RUNTIME_DIR"/libpod/tmp/pause.pid ] || { echo "FAIL: host podman saved no namespace"; exit 1; }

setsid sudo -n unshare -m --propagation private \
	setpriv --reuid="$(id -u)" --regid="$(id -g)" --clear-groups \
	env HOME="$HOME" PATH="$PATH" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
	"$image" list < /dev/null > "$work"/out 2>&1 &

for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
	grep -q -e '^ID ' -e '^Error' "$work"/out 2>/dev/null && break
	sleep 1
done

if grep -q '^ID ' "$work"/out; then
	echo "PASS: list works with a saved namespace that lacks the mount"
else
	echo "FAIL:"; cat "$work"/out
	exit 1
fi
