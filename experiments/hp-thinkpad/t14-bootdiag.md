# T14 boot candidate, 2026-09-21

The owner installed the preceding Dragon image on the HP in 2m42s. SSH
confirmed its running kernel is 7.2.6-1-aarch64-ARCH. The T14 cannot reach the
installer from either USB-A or USB-C, and its keyboard does not work in the
initramfs rescue shell. IMG_0397 shows missing qcom/gen70500_sqe.fw and a
deferred LPASS pin-controller probe. It does not show the error that launched
the shell. The last owner-confirmed working T14 baseline is earlier prototype 0.1.2,
using 7.0.0-31-generic. Kernel configuration, device trees and boot assembly
also differ; the version number alone does not identify the regression.

Current build instructions: [hardware README](README.md). The staged-root
repacking commands below describe the historical investigation only.

## Changes

- Early package 0.3 explicitly includes gen70500 SQE, GMU and ZAP firmware.
  The previous initramfs omitted these despite their presence in the live root.
- The ARM UKI entry shows messages and disables the Plymouth runtime hook.
- Media discovery gets a 30-second device-resolution timeout; Archiso's
  search function otherwise defaults to four seconds. This is an allowance
  for slow enumeration, not a confirmed diagnosis.
- An opt-in, one-shot emergency report shows model, arguments, block/input
  devices and recent relevant kernel messages. It covers both mkinitcpio
  emergency hooks and Archiso's direct rescue-shell calls. It writes only to
  the console and requires no working keyboard.
- The live system and offline repository both receive early package 0.3.

## Build provenance

Upstream was fetched again before this task. ISO dragon remains f97a775 and
runtime dragon remains 66a33c3. Rebuild the existing t14-power ISO's root,
initramfs and UKI with the retired staged-root repacking helper. Preserve
the existing kernel, DTs, boot partition and application package versions.
The package-recipe master branch has newer application updates, but those
are not incorporated in this controlled boot candidate.

Use the ARM container for prepare/initramfs and the historical native builder for
finish, with the repository mounted at /repo. Extract the previous SquashFS
into build/hp-thinkpad/t14-bootdiag-root first and build early package 0.3.
The initramfs stage requires a privileged container for arch-chroot mounts.
The finish stage replays the original ISO's boot layout with xorriso.

The report wrapper is tested with mkinitcpio's BusyBox ash for command-line
gating, ordering, argument forwarding and return status. Final initramfs
checks require all three GPU firmware files and the runtime hook alongside
the previous power/storage and board-firmware checks.

Physical T14 boot remains unverified. Copy the completed image to ~/ISOs
and stop for owner testing; do not write a USB or start another build.
