#!/usr/bin/env bash
#
# repack.sh - build the vegas26 RRO overlays, and optionally bake them into an
# ext4 LineageOS microG GSI so they apply with NO root for anyone who flashes it.
#
# This is a REFERENCE script. Run it in WSL/Ubuntu (or any Linux). It is not fully
# hardened; read it, and verify the result on-device (`cmd overlay list` should show
# both overlays enabled after boot). See README Part 5.
#
# Requirements (apt install): e2fsprogs android-sdk-libsparse-utils
#   plus Android SDK build-tools on PATH (aapt2, apksigner) and a JDK (keytool).
#
# Usage:
#   ./repack.sh build                      # build both overlay APKs into ./out/
#   ./repack.sh bake  LineageOS-...-ext4-gsi.img.xz   # build + inject into the GSI
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/out"
ANDROID_JAR="${ANDROID_JAR:?set ANDROID_JAR to an android.jar, e.g. \$ANDROID_SDK/platforms/android-36.1/android.jar}"
OVERLAY_DIR_IN_IMG="system/product/overlay"   # verify after mounting; GSIs are often nested one level

build_one() {
  # $1 = overlay source dir (contains AndroidManifest.xml + res/)
  local src="$1" name; name="$(basename "$src")"
  echo ">> building overlay: $name"
  rm -rf "$OUT/$name"; mkdir -p "$OUT/$name"
  aapt2 compile --dir "$src/res" -o "$OUT/$name/compiled.zip"
  aapt2 link -o "$OUT/$name/unsigned.apk" -I "$ANDROID_JAR" \
     --manifest "$src/AndroidManifest.xml" --min-sdk-version 30 "$OUT/$name/compiled.zip"
  [ -f "$OUT/debug.keystore" ] || keytool -genkeypair -keystore "$OUT/debug.keystore" \
     -alias k -storepass android -keypass android -dname "CN=rro" -validity 10000 -keyalg RSA -keysize 2048
  apksigner sign --ks "$OUT/debug.keystore" --ks-pass pass:android \
     --out "$OUT/${name}.apk" "$OUT/$name/unsigned.apk"
  echo "   -> $OUT/${name}.apk"
}

do_build() {
  mkdir -p "$OUT"
  build_one "$HERE/overlays/cutout"
  build_one "$HERE/overlays/aperture-aux"
}

do_bake() {
  local xz="${1:?usage: repack.sh bake <...-ext4-gsi.img.xz>}"
  do_build
  echo ">> decompressing GSI"
  cp "$xz" "$OUT/"; local base; base="$(basename "$xz" .xz)"
  ( cd "$OUT" && xz -dk "$(basename "$xz")" )
  local img="$OUT/$base"

  # If it is a sparse image, convert to raw first:  simg2img "$img" "$img.raw" && mv "$img.raw" "$img"
  echo ">> fsck + grow a little slack"
  e2fsck -fy "$img" || true
  truncate -s +8M "$img"; resize2fs "$img"

  echo ">> inject overlays via debugfs (no mount needed)"
  # Copy the SELinux context from an existing overlay in the image onto the new files.
  local ctx; ctx="$(debugfs -R "ea_list $OVERLAY_DIR_IN_IMG" "$img" 2>/dev/null | grep -o 'security.selinux.*' || true)"
  for name in cutout aperture-aux; do
    debugfs -w -R "rm $OVERLAY_DIR_IN_IMG/${name}.apk" "$img" 2>/dev/null || true
    debugfs -w -R "write $OUT/${name}.apk $OVERLAY_DIR_IN_IMG/${name}.apk" "$img"
    debugfs -w -R "sif $OVERLAY_DIR_IN_IMG/${name}.apk mode 0100644" "$img"
    debugfs -w -R "sif $OVERLAY_DIR_IN_IMG/${name}.apk uid 0" "$img"
    debugfs -w -R "sif $OVERLAY_DIR_IN_IMG/${name}.apk gid 0" "$img"
    # Set SELinux label to match siblings (typically u:object_r:system_file:s0):
    debugfs -w -R "ea_set $OVERLAY_DIR_IN_IMG/${name}.apk security.selinux u:object_r:system_file:s0\\000" "$img"
  done

  echo ">> fsck + recompress"
  e2fsck -fy "$img" || true
  ( cd "$OUT" && xz -9 -T0 -k "$base" )
  echo "DONE -> $OUT/${base}.xz  (flash to system in fastbootd; see README Part 2)"
}

case "${1:-}" in
  build) do_build ;;
  bake)  shift; do_bake "${1:-}" ;;
  *) echo "usage: $0 {build | bake <...-ext4-gsi.img.xz>}"; exit 1 ;;
esac
