#!/bin/bash
# Finish arch-independent packaging of an already prepared Dragon ARM root.
set -euo pipefail
source_root=/proc/1/root
stage=/work/native-final
[[ -r $source_root/var/cache/work/build_date ]]
[[ ! -e $stage ]]
mkdir -p "$stage"
export SOURCE_DATE_EPOCH=$(cat "$source_root/var/cache/work/build_date")
export OMARCHY_ARCH=aarch64 OMARCHY_MEDIA_TARGET=aarch64/snapdragon
# Load the exact builder's functions without running its CLI entry point.
sed '/^while getopts /,$d' "$source_root/usr/bin/mkarchiso" > "$stage/archiso-functions.sh"
source "$stage/archiso-functions.sh"
source "$source_root/var/cache/profiledef.sh"
app_name=mkarchiso
quiet=n
rm_work_dir=0
work_dir=$stage
out_dir=/out
isofs_dir=$stage/iso
pacstrap_dir=$source_root/var/cache/work/aarch64/airootfs
efibootimg=$stage/efiboot.img
image_name="omarchy-dragon-hp-thinkpad-${iso_version}-${arch}.iso"
[[ ! -e $out_dir/$image_name ]]
cp -a "$source_root/var/cache/work/iso" "$isofs_dir"
cp -a "$source_root/var/cache/work/efiboot.img" "$efibootimg"
printf 'Native finalization; SOURCE_DATE_EPOCH=%s\n' "$SOURCE_DATE_EPOCH"
mksquashfs -version | head -1
_mkairootfs_squashfs
_mkchecksum
_build_iso_image
chown "${HOST_UID}:${HOST_GID}" "$out_dir/$image_name"
printf '%s\n' "$out_dir/$image_name" > "$stage/result"
