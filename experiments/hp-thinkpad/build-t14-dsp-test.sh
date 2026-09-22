#!/bin/bash
# Reuse the validated bootdiag payload; change only the experimental GRUB menu.
set -euo pipefail
cd /repo
input=release/omarchy-dragon-t14-bootdiag-2026.09.21-aarch64.iso
output=release/omarchy-dragon-t14-dsp-test-2026.09.21-aarch64.iso
[[ -s $input && ! -e $output ]]
xorriso -indev "$input" -outdev "$output" \
    -boot_image any replay -volume_date uuid 2026092116355200 \
    -map experiments/hp-thinkpad/grub-t14-dsp-test.cfg /boot/grub/grub.cfg
chown 1000:1000 "$output"
