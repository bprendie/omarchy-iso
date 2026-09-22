#!/usr/bin/env bash
# Finish the HP mic + T14s WCN7850 candidate from the tested Dragon live ISO.
set -euo pipefail
cd /repo

work=/repo/build/hp-thinkpad
root=$work/hp-mic-root
stage=$work/combo-stage
input=/repo/release/omarchy-dragon-t14-dsp-test-2026.09.21-aarch64.iso
output=/repo/release/omarchy-dragon-hp-t14-bluetooth-mic-2026.09.21-aarch64.iso
mirror=$root/var/cache/omarchy/mirror/offline
package=omarchy-hw-t14s-bluetooth-experimental-0.1-1-aarch64.pkg.tar.xz
dtb=$stage/boot/dtbs/qcom/x1e78100-lenovo-thinkpad-t14s.dtb

[[ -s $input && ! -e $output && -d $root/usr && -s $stage/boot/omarchy-live.efi ]]
[[ ! -e $stage/airootfs.sfs && -s $mirror/$package ]]
[[ $(sha256sum "$dtb" | cut -d' ' -f1) == 8061768e6ac74eaf3cc0039e060cb63c1a56d452850c7dcc6e756aa9f5cde3fb ]]
grep -q '"omarchy-hw-t14s-bluetooth-experimental"' "$root/usr/share/omarchy-iso/platforms.json"
grep -q "VA DMIC MUX1' DMIC2" "$root/usr/share/alsa/ucm2/Qualcomm/x1e80100/HP-DMIC2EnableSeq.conf"
grep -q '^omarchy-hw-t14s-bluetooth-experimental 0.1-1$' "$stage/pkglist.aarch64.txt"

python3 - "$stage/boot/omarchy-live.efi" "$dtb" <<'PY'
from pathlib import Path
import sys
uki, dtb = (Path(arg).read_bytes() for arg in sys.argv[1:])
if uki.count(dtb) != 1:
    raise SystemExit('Live UKI does not contain the exact T14s trial DTB once')
PY

mksquashfs "$root" "$stage/airootfs.sfs" -noappend -comp xz -Xbcj arm -b 1M -no-progress \
  -action 'uncompressed@subpathname(var/cache/omarchy/mirror/offline)'
(cd "$stage" && sha512sum airootfs.sfs > airootfs.sha512)

xorriso -indev "$input" -outdev "$output" -boot_image any replay \
  -volume_date uuid 2026092116355200 \
  -map "$stage/airootfs.sfs" /arch/aarch64/airootfs.sfs \
  -map "$stage/airootfs.sha512" /arch/aarch64/airootfs.sha512 \
  -map "$stage/boot/omarchy-live.efi" /arch/boot/aarch64/omarchy-live.efi \
  -map "$stage/pkglist.aarch64.txt" /arch/pkglist.aarch64.txt

chown 1000:1000 "$output"
echo "Built $output"
