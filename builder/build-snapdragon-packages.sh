#!/bin/bash
# Add board packages without replacing Dragon's published Omarchy repository.
set -euo pipefail
config=${1:?online pacman configuration}
work=/var/cache/omarchy-hardware
repo=$work/repo
pacman --noconfirm -S --needed git python curl 7zip innoextract squashfs-tools libisoburn zstd alsa-utils alsa-ucm-conf dtc
python /hardware/fetch-firmware.py --work-dir "$work"
python /hardware/prepare-packages.py --work-dir "$work"
bash /builder/fetch-snapdragon-recipes.sh "$work/hardware"

# Build the exact tested Bluetooth tree from the selected Arch kernel package.
# Fail closed when the kernel DT changes; do not overwrite an unknown tree.
mkdir -p "$work/kernel" "$repo"
pacman --config "$config" --noconfirm -Sw --cachedir "$work/kernel" linux-aarch64
kernel=$(pacman --config "$config" -Sp --print-format '%n %f' linux-aarch64 | awk '$1 == "linux-aarch64" { print $2 }')
[[ -n $kernel && $kernel != *$'\n'* ]]
kernel_release=${kernel#linux-aarch64-}
kernel_release=${kernel_release%-aarch64.pkg.tar.*}
[[ $kernel_release == 7.2.6-1 ]] || { echo "Camera packages require reviewed kernel 7.2.6-1" >&2; exit 1; }
pacman --config "$config" --noconfirm -S --needed linux-aarch64-headers
[[ $(pacman -Q linux-aarch64-headers | awk '{ print $2 }') == "$kernel_release" ]] || { echo "Camera headers do not match selected kernel" >&2; exit 1; }
headers_root=/usr/lib/modules/$kernel_release-aarch64-ARCH/build/include
[[ -f $headers_root/dt-bindings/clock/qcom,x1e80100-camcc.h && -f $headers_root/../Module.symvers ]]
base=$work/base
mkdir -p "$base"
bsdtar -xf "$work/kernel/$kernel" -C "$base" boot/dtbs/qcom/x1e78100-lenovo-thinkpad-t14s.dtb
bsdtar -xf "$work/kernel/$kernel" -C "$base" boot/dtbs/qcom/x1e80100-hp-elitebook-ultra-g1q.dtb
base_dtb=$base/boot/dtbs/qcom/x1e78100-lenovo-thinkpad-t14s.dtb
echo "f21573bd4946bf7118e467326b22de228cfd64c61255ed7b51baa71185808df9  $base_dtb" | sha256sum -c -
bt=$work/hardware/omarchy-hw-t14s-bluetooth-experimental
mkdir -p "$bt"
cp /hardware/t14-bluetooth-package/* "$bt/"
dtc -@ -I dts -O dtb -o "$work/t14.dtbo" /hardware/t14-bluetooth.dtso
fdtoverlay -i "$base_dtb" -o "$bt/x1e78100-lenovo-thinkpad-t14s.dtb" "$work/t14.dtbo"
echo "86a59910f88996672e51b302e176a2b2b81ee9b7d18009b9c64706d0a9a8a9db  $bt/x1e78100-lenovo-thinkpad-t14s.dtb" | sha256sum -c -
# Live image gets the same tree through customize_airootfs, before ukify.
install -Dm644 "$bt/x1e78100-lenovo-thinkpad-t14s.dtb" /var/cache/airootfs/root/t14-bluetooth.dtb

# The shared SoC overlay is compiled once; board overlays retain their own
# sensor, power, and graph wiring.
cpp -P -nostdinc -undef -D__DTS__ -I "$headers_root" -x assembler-with-cpp \
  /hardware/x1e80100-camera.dtso > "$work/x1e80100-camera.dts"
dtc -@ -I dts -O dtb -o "$work/x1e80100-camera.dtbo" "$work/x1e80100-camera.dts"
camera=$work/hardware/omarchy-hw-t14s-camera-experimental
mkdir -p "$camera"
cp /hardware/t14-camera-package/* "$camera/"
cpp -P -nostdinc -undef -D__DTS__ -I "$headers_root" -x assembler-with-cpp \
  /hardware/t14-camera.dtso > "$work/t14-camera.dts"
dtc -@ -I dts -O dtb -o "$work/t14-camera.dtbo" "$work/t14-camera.dts"
fdtoverlay -i "$bt/x1e78100-lenovo-thinkpad-t14s.dtb" \
  -o "$camera/x1e78100-lenovo-thinkpad-t14s.dtb" \
  "$work/x1e80100-camera.dtbo" "$work/t14-camera.dtbo"
echo "93ffd63948e6ed79a2c459ab1a5079d848f06d0437352a978ee8322a0c3abf37  $camera/x1e78100-lenovo-thinkpad-t14s.dtb" | sha256sum -c -
install -Dm644 "$camera/x1e78100-lenovo-thinkpad-t14s.dtb" /var/cache/airootfs/root/t14-camera.dtb
hp_base_dtb=$base/boot/dtbs/qcom/x1e80100-hp-elitebook-ultra-g1q.dtb
echo "4116ab5c1cac1e694ab56e19c3c105374bf205eab55bd92b6cd234d42d2a271b  $hp_base_dtb" | sha256sum -c -
hp_camera=$work/hardware/omarchy-hw-hp-camera-experimental
mkdir -p "$hp_camera"
cp /hardware/hp-camera-package/{PKGBUILD,Makefile,ov05c10.c,install-dtb,85-hp-camera-dtb.hook,hp-camera.install,README.md} "$hp_camera/"
cpp -P -nostdinc -undef -D__DTS__ -I "$headers_root" -x assembler-with-cpp \
  /hardware/hp-camera.dtso > "$work/hp-camera.dts"
dtc -@ -I dts -O dtb -o "$work/hp-camera.dtbo" "$work/hp-camera.dts"
fdtoverlay -i "$hp_base_dtb" -o "$hp_camera/x1e80100-hp-elitebook-ultra-g1q.dtb" \
  "$work/x1e80100-camera.dtbo" "$work/hp-camera.dtbo"
echo "090e8e46693c61bf0236df43060db55ac6549d15ee2cd3c234c8de57c4b4e962  $hp_camera/x1e80100-hp-elitebook-ultra-g1q.dtb" | sha256sum -c -
install -Dm644 "$hp_camera/x1e80100-hp-elitebook-ultra-g1q.dtb" /var/cache/airootfs/root/hp-camera.dtb
id omarchy-builder &>/dev/null || useradd -m omarchy-builder
for source in "$work"/hardware/*; do
  chown -R omarchy-builder:omarchy-builder "$source"
  (cd "$source" && runuser -u omarchy-builder -- makepkg --nodeps --noconfirm --force)
  shopt -s nullglob
  packages=("$source"/*.pkg.tar.zst "$source"/*.pkg.tar.xz)
  ((${#packages[@]} == 1))
  cp "${packages[@]}" "$repo/"
done
repo-add "$repo/omarchy-hardware.db.tar.gz" "$repo"/*.pkg.tar.*
# A distinct, first-priority repository preserves the published Omarchy channel.
awk -v repo="$repo" '
  /^\[/ && $0 != "[options]" && !inserted {
    print "[omarchy-hardware]\nSigLevel = Optional TrustAll\nServer = file://" repo "\n"
    inserted=1
  }
  { print }
' "$config" > "$config.hardware"
mv "$config.hardware" "$config"
