# Dragon HP/ThinkPad Phase 0–1 evidence — 2026-09-16

## Installed HP, read-only SSH inventory

- DMI: `HP` / `HP EliteBook Ultra G1q 14 inch Notebook AI PC` / `8CBE`.
  Running DT model: `HP EliteBook Ultra G1q`.
- Kernel `7.2.6-1-aarch64-ARCH`; installed Omarchy runtime/settings dev
  `4.0.0.r2015.g4930677-1`; `linux-aarch64-pkgbase-shim 1-3`.
- Experimental HP package `0.1-1` and common early package `0.1-1` installed.
  Exact HP topology SHA-256 is
  `aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5`,
  matching the physically tested earlier prototype topology.
- HP ADSP and cDSP remote processors are `running` with the board paths
  provided by the HP package. ALSA card 0 and PipeWire speaker/microphone nodes
  exist. The owner hears no audio. Kernel reports a Qualcomm APM command
  timeout and an earlier no-backend warning; PipeWire reports an invalid PCM
  open for one HDMI route. Speaker failure cause is not established.
- `cam -l` has no camera; no `/dev/video*` or `/dev/media*` was observed. The
  first ISO did not include the HP OV05C10 driver or board camera DT graph.
- cDSP FastRPC probe fails with `-12`; `/dev/fastrpc-adsp` exists but
  `/dev/fastrpc-cdsp` does not. NPU execution is blocked at transport.
- Wi-Fi and Bluetooth work by owner report. Installed `/boot` is not readable
  without privilege; UKI/Limine state is not claimed from this SSH inventory.

## ThinkPad Dragon inventory

No installed Dragon ThinkPad was reachable for Phase 0. The old earlier prototype SSH
address `10.0.0.42` timed out. Its previous audio, RGB camera and QNN HTP
results were obtained on the Ubuntu kernel, not Dragon. Keyboard backlight
remained unresolved, and its TrackPoint cable was disconnected pending a
replacement keyboard at the time of those tests.

## Phase 1 package audit and correction

The first ThinkPad package `0.1-1` omitted its AudioReach topology. In the
retained Ubuntu firmware archive the board topology is a symlink to the Romulus
topology; the previous extractor accepted only regular files and looked for a
top-level path. The `0.2-1` extractor follows that exact archive member and
materializes both the board path and the top-level name used by firmware
loading. Both topology files hash to the same physically tested bytes as the
HP topology above. It fails if either board's DSP firmware pair or the
ThinkPad topology is missing. It regenerates clean payload trees and records
per-board input and staged firmware hashes.

Both board packages `0.2-1` built with makepkg and were indexed into the
ignored local repository. The common early package remains `0.1-1`; its
initramfs hook is reused by both boards. Exact DMI profiles select the board
packages in the installed target. The live image includes both packages so
either board can boot the same media.

Remaining gates: inspect the new ISO's boot image/package closure; obtain the
owner's physical HP and ThinkPad installs; validate installed update/reboot
behavior. No hardware PASS is inferred from the package build.
