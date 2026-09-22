# Dragon HP / ThinkPad local ISO experiment

This experiment keeps Dragon's Arch Linux ARM kernel, live systemd UKI/device-tree
selection, Quattro installer, and installed Limine workflow. It does not import
oma_snap's Ubuntu kernel provider, retained-set activation, or menu writer.

Baseline ISO source: cac0cc26f8f295f5cfa94f1427aa2e90454814d0 (dragon).
Runtime: omacom/omarchy dragon, 66a33c339914cfa0e41ec1fce8f198ea779b8aea.
Package recipes: omacom/omarchy-pkgs master, 5fe236736607b1a9f6df3c3a4b364515f70eed53.
Two pending team recipes are taken from PR 221 (firmware extraction) and PR 222
(kernel metadata shim); exact fetched revisions are recorded in build inputs.
The local runtime recipe includes the Limine/Snapper dependencies on ARM UEFI.
The local settings recipe retains ARM mkinitcpio and Limine configuration/templates,
following the boot requirement addressed by PR 380. This is an experimental
assembly, not a claim that those package changes have merged upstream.

## September 21 checkpoint — read this first

This branch records the tested local HP/T14 assembly and its known regressions;
it is not a release or an upstream-ready PR. Current ISO source base is Dragon
`f97a775823c53069c003a4c620692cdb11fe7de0` (fetched again before this checkpoint).
The older baseline and commands below describe the investigation's history.

Both machines clean-installed the combined image
`omarchy-dragon-hp-t14-bluetooth-mic-2026.09.21-aarch64.iso` with kernel 7.2.6-1.
Speakers work on both; HP speech capture is owner-confirmed with one active PCM
channel. T14 microphone/media keys work. Bluetooth headphone playback works on
both; automatic reconnection is not fully validated.

**Known T14 regression:** switching Bluetooth off drops the Wi-Fi PCIe link.
The isolated test captured Wi-Fi removal and kernel waits; a warm reboot left
Wi-Fi absent, while power-off/start restored it. The HP owner reports independent
radio toggles work. Live dependency inspection finds both Wi-Fi and Bluetooth
consumers on HP's WCN PMU, but only Bluetooth on T14. The missing Wi-Fi power
consumer is the leading correction, not yet a validated fix. Do not deploy the
retained `t14-bluetooth-wifi-pmu.dtso` trial: its boot image froze and also changed
the UKI's `.dtbauto` layout to `.dtb`, confounding that test.

Camera, cDSP/NPU, suspend and battery validation remain open. HP function keys
remain deferred. See [today's workbook](../../plans/2026-09-21-hp-t14-workbook.md)
for evidence, test limits, and the next steps.

### Rebuild and publication boundary

[Firmware inputs](inputs/README.md) records upstream sources, extraction paths,
archive hashes and exact staged-file hashes. Firmware, package archives, ISO
images and private diagnostic logs are not part of this source checkpoint.
Vendor redistribution rights are not established by a hash or a successful boot.

This is **not yet a standalone clean-checkout build**. `prepare-packages.py`
currently consumes retained oma_snap packages; later ISO scripts require staged
roots and earlier ISO artifacts. Those local dependencies are explicitly retained
as a follow-up rather than represented as a reproducible public release. Before
an upstream PR/release, replace them with pinned input acquisition and repeat a
clean build. Preserve Dragon's package ownership and boot-image generation.

### Checkpoint validation

Shell/Python/JSON syntax checks and the BusyBox boot-diagnostic test pass.
The selected existing unit suite ran 45 tests: 42 passed and three
`Aarch64CustomizeTest` cases failed because their fixture lacks `/etc/pacman.conf`,
now read by sandbox cleanup. The Snapdragon fixture also needs the new required
firmware/module inventory. This checkpoint records those test-fixture gaps;
it does not claim a green suite. No ISO was rebuilt for this commit.

## Hardware payload

- HP EliteBook Ultra G1q, exact DMI product `HP EliteBook Ultra G1q 14 inch Notebook AI PC`.
- ThinkPad T14s Gen 6 LCD, exact tested product `21N10000US`.
- HP GPU/ADSP/cDSP firmware and audio topology/UCM aliases.
- Lenovo GPU/ADSP/video firmware and topology, with the physically validated cDSP pair.
- Early display/input module dependencies and explicit board firmware in initramfs.
- Camera userspace packages available for installed systems.

Vendor firmware is staged under `/usr/lib/firmware/updates`, using the paths
requested by Dragon's actual device trees. Original package hashes are checked
against the oma_snap manifests. Firmware binaries and built packages stay in
ignored build directories. This local image is not a public firmware release.
No Qualcomm SDK/QNN runtime is distributed, and NPU execution on Dragon remains
physically untested. The earlier QNN successes used the oma_snap kernel.

Live DSP auto-start remains Yoga-only, preserving Dragon's USB-media guards.
HP/ThinkPad live battery/audio/hotplug may therefore differ from installed behavior.

## Camera boundary

Arch ARM linux-aarch64 7.2.6-1 includes X1E80100 CAMSS, camera clocks, and CCI.
Its HP DT lacks the CCI/CAMSS/camera graph used by our Ubuntu overlay.
The oma_snap OV05C10 source successfully compiled against matching Arch headers
in this experiment (`build/hp-thinkpad/camera-driver.log`). It is not installed
in the ISO without a compatible device tree and capture validation.

Next camera work is a board DT plus sensor-driver package compatible with the
Arch CAMSS binding. Do not reuse Ubuntu's CSI-PHY overlay or ABI-specific modules.
Validate the complete DT against the selected kernel, then test physical libcamera
and PipeWire capture. Compiling the sensor driver is not a hardware pass.

## Build

The local `build/hp-thinkpad/` directory contains cloned runtime/package recipes,
a hash-verified snapshot of the published ARM Omarchy repository, and builder logs.
`prepare-packages.py ../oma_snap` stages firmware recipes from retained packages.
`early/` supplies a build-only initramfs hook (no runtime daemon or polling).

Build staged packages with `build/hp-thinkpad/build-packages.sh` in the dedicated
ARM package container, then run from this checkout:

```sh
OMARCHY_BUILD_DISABLE_SANDBOX=1 ./bin/omarchy-iso-make \
  --arch aarch64 --media-target aarch64/snapdragon \
  --local-source build/hp-thinkpad/omarchy build/hp-thinkpad/omarchy-pkgs \
  --local-repo build/hp-thinkpad/repo --keep-pkg-cache --no-boot-offer
```

The sandbox switch is scoped to the disposable build: QEMU user emulation does
not support pacman's Landlock sandbox. It does not change host configuration.

Acceptance order: inspect packaged firmware/hooks/DTBs, boot the full ISO in
ARM UEFI QEMU, then physical HP/ThinkPad live boot and installation. VM success
cannot establish panel, NPU, camera, audio, charging or suspend support.

Pinned pending package recipe revisions:
- qcom-firmware-extract: 4a232b639957a251bfe9220d7d253b95fe5ae635 (PR 221).
- linux-aarch64-pkgbase-shim: 3951d934ccd30b72b68f3d954a220b830fb8143d (PR 222).

## Current handoff boundary

Owner requested a pause immediately after ISO assembly and checksum generation.
Do not launch the VM or write USB media as part of this build. Physical burning
and initial boot testing are owner-operated. HP camera capture is not enabled
in this first image; its driver compile evidence is retained separately.

## Build continuation

The first full resolution found a missing `libpisp` in the current ARM mirror.
The retained signed `libpisp-1.5.0-1-aarch64.pkg.tar.xz` from oma_snap was checked
against `manifests/camera-offline-packages.sha256` and added to the local repository.
The completed Dragon runtime/settings/Neovim packages were also indexed there.
The continuation uses the supported prebuilt-repository path, avoiding a duplicate
runtime build:

```sh
OMARCHY_BUILD_DISABLE_SANDBOX=1 ./bin/omarchy-iso-make \
  --arch aarch64 --media-target aarch64/snapdragon --edge \
  --local-repo build/hp-thinkpad/repo --keep-pkg-cache --no-boot-offer
```

Logs: `build/hp-thinkpad/iso-build.log` (first attempt) and
`build/hp-thinkpad/iso-build-2.log` (continuation).

The first package-triggered initramfs exposed a live hook reset overriding the
experimental hook. The live hook list now explicitly retains `dragon_hp_thinkpad`,
and final image inspection checks the early LCD module and both boards' DSP firmware alongside the archiso runtime hooks.
The final live initramfs is rebuilt by customize_airootfs after package hooks.

## Native final packaging

The ARM build completed package installation, the final initramfs checks, a UKI
with 32 DTB sections and HWIDs, and GRUB/FAT boot media. Its xz compression under
QEMU remained slow, so that container was paused after filesystem cleanup.
`native-finalize.sh` uses the same mksquashfs 4.7.5 natively, reads the prepared
root through the shared PID namespace, and copies the ISO staging tree separately.
It loads the actual builder's archiso functions, uses its unchanged profile options
and SOURCE_DATE_EPOCH, then runs squashfs, the root-image checksum, and xorriso.
No package, kernel, firmware, DTB, or boot configuration changes in this step.
The native output is named `omarchy-dragon-hp-thinkpad-<date>-aarch64.iso`.
No VM is launched. The paused emulated builder is retained as a fallback until
native finalization succeeds, then only these experiment containers are stopped.
