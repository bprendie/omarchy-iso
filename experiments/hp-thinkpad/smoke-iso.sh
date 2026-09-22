#!/bin/bash
# Boot the complete candidate without an installation disk or guest network.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
iso=$(realpath "${1:?Usage: smoke-iso.sh path/to/candidate.iso}")
run="$root/build/hp-thinkpad/vm-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run"
printf '%s\n' "$run"
sha256sum "$iso" > "$run/iso.sha256"
docker run --rm --network none --user "$(id -u):$(id -g)" --name dragon-hp-live-test \
  -v "$iso:/images/live.iso:ro" -v "$run:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu max -m 8192 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci \
  -device usb-kbd -device usb-tablet \
  -drive if=none,id=live,format=raw,readonly=on,file=/images/live.iso \
  -device usb-storage,drive=live,removable=on,bootindex=1 \
  -nic none \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial -qmp unix:/work/qmp.sock,server=on,wait=off \
  -display none -monitor none -no-reboot
