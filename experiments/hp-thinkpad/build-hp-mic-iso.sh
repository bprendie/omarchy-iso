#!/bin/bash
# Package the HP mic UCM trial over the owner-booted shared DSP ISO.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo"

work=$repo/build/hp-thinkpad
root=$work/hp-mic-root
stage=$work/hp-mic-stage
input=$repo/release/omarchy-dragon-t14-dsp-test-2026.09.21-aarch64.iso
output=$repo/release/omarchy-dragon-hp-mic-2026.09.21-aarch64.iso
package=omarchy-hw-hp-experimental-0.3-1-any.pkg.tar.zst
source_package=$work/hardware/omarchy-hw-hp-experimental/$package
mirror=$root/var/cache/omarchy/mirror/offline

case ${1:?prepare, index or finish} in
prepare)
    [[ -s $input && -s $source_package && ! -e $root && ! -e $stage && ! -e $output ]]
    echo 'Copying the validated live root'
    cp -a --reflink=auto "$work/t14-bootdiag-root" "$root"
    chmod u+w "$root"
    mkdir -p "$stage"
    cp "$source_package" "$mirror/$package"
    echo 'Prepared copied live root'
    ;;
index)
    [[ -s $mirror/$package && -e $mirror/offline.db.tar.gz && ! -e $stage/airootfs.sfs ]]
    repo-remove "$mirror/offline.db.tar.gz" omarchy-hw-hp-experimental
    repo-add "$mirror/offline.db.tar.gz" "$mirror/$package"
    rm "$mirror/omarchy-hw-hp-experimental-0.2-1-any.pkg.tar.zst"
    echo 'Prepared offline package mirror'
    ;;
finish)
    [[ -s $input && -s $mirror/$package && -d $root/usr && ! -e $stage/airootfs.sfs && ! -e $output ]]

# The live ISO reuses the already validated UKI/initramfs. Firmware is unchanged;
# the package upgrade only needs its UCM files and offline package metadata.
mask=$root/etc/pacman.d/hooks/90-mkinitcpio-install.hook
[[ ! -e $mask && ! -L $mask ]]
mkdir -p "${mask%/*}"
ln -s /dev/null "$mask"
trap 'rm -f "$mask"' EXIT
"$root/usr/bin/arch-chroot" -r "$root" pacman -U --noconfirm "/var/cache/omarchy/mirror/offline/$package"
rm "$mask"
trap - EXIT

"$root/usr/bin/arch-chroot" -r "$root" pacman -Q omarchy-hw-hp-experimental
"$root/usr/bin/arch-chroot" -r "$root" pacman -Q > "$stage/pkglist.aarch64.txt"
[[ $(readlink "$root/usr/share/alsa/ucm2/conf.d/x1e80100/X1E80100-HP-ELITEBOOK-ULTRA-G1Q.conf") == ../../Qualcomm/x1e80100/HP-ELITEBOOK-ULTRA-G1Q.conf ]]
grep -q "VA DMIC MUX1' DMIC2" "$root/usr/share/alsa/ucm2/Qualcomm/x1e80100/HP-DMIC2EnableSeq.conf"

echo 'Packing live root and replaying the validated EFI boot layout'
mksquashfs "$root" "$stage/airootfs.sfs" -noappend -comp xz -Xbcj arm -b 1M -no-progress \
  -action 'uncompressed@subpathname(var/cache/omarchy/mirror/offline)'
(cd "$stage" && sha512sum airootfs.sfs > airootfs.sha512)
xorriso -indev "$input" -outdev "$output" -boot_image any replay \
  -volume_date uuid 2026092116355200 \
  -map "$stage/airootfs.sfs" /arch/aarch64/airootfs.sfs \
  -map "$stage/airootfs.sha512" /arch/aarch64/airootfs.sha512 \
  -map "$stage/pkglist.aarch64.txt" /arch/pkglist.aarch64.txt
    chown 1000:1000 "$output"
    echo "Built $output"
    ;;
*) exit 2 ;;
esac
