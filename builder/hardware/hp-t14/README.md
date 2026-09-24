# HP EliteBook and ThinkPad T14s Snapdragon support

This directory contains board firmware preparation, audio configuration and
boot dependencies used by the Omarchy Snapdragon ISO builder. It uses Dragon's
Arch Linux ARM kernel, systemd UKI hardware selection, installer and Limine flow.

## Build from a clean checkout

With Docker available and ARM64 execution supported (native ARM64 or configured
binfmt/QEMU emulation), run from the repository root:

```sh
git submodule update --init --recursive
./bin/omarchy-iso-make-snapdragon
```

For QEMU user emulation that cannot implement pacman's Landlock sandbox, prefix
the command with `OMARCHY_BUILD_DISABLE_SANDBOX=1`. This changes the disposable
build configuration; the live/installed pacman configuration retains sandboxing.

The launcher fetches pinned official Dragon runtime and package sources and
passes them to the standard builder's `--local-source` mode. The package channel
currently lacks two required ARM packages and its settings recipe drops ARM UEFI
boot files, so the launcher applies the small checked-in ARM UEFI recipe patch.
The hardware builder fetches the team's pending kernel-metadata and firmware
extraction recipes by commit. None of this requires a preexisting source checkout.
Remove these temporary recipe adaptations when the package channel supplies the
same ARM contracts. Pins and patch are in `builder/prepare-snapdragon-sources.sh`,
`builder/fetch-snapdragon-recipes.sh`, and `builder/patches/snapdragon-arm-package-config.patch`.

The builder installs its extraction tools, downloads the [pinned inputs](inputs/README.md),
verifies their hashes, extracts the selected firmware, builds AudioReach topology,
generates HP UCM, and builds the board packages in a separate local hardware
repository. Dragon's edge channel supplies remaining dependencies. No
sibling checkout, manually built package archive, prior ISO or extracted root
is required. Output follows the normal launcher naming under `release/`.

The vendor downloads include a 4.15 GB Ubuntu ISO; budget disk space for both
archives and extraction. Builds require access to the pinned vendor URLs and
the selected Arch/Omarchy package mirrors. Firmware is pinned; the normal
rolling package channels are not a bit-for-bit ISO lockfile.

At the USB boot menu, HP/T14 owners select **Omarchy HP EliteBook / ThinkPad T14s**
for the tested early-DSP path. The standard entry retains the DSP guard used by
other Snapdragon boards.

The T14 Bluetooth DTB is built from the selected kernel's base tree and checked
against the tested input/output hashes. A different kernel DTB fails the build
for review instead of silently applying stale board data. The live UKI retains
`.dtbauto` sections and hardware-ID selection. This radio candidate adds the
T14 Wi-Fi consumer to the WCN7850 PMU; package `0.2-1` accepts the exact kernel
base and previously shipped Bluetooth-only DTB for migration. The radio image
and subsequent camera image have installed and booted on T14.
Radio acceptance remains incomplete; see the hardware status below.

## Firmware-only verification

This optional native container isolates input preparation from ISO assembly:

```sh
docker build -t omarchy-firmware-builder:local -f builder/hardware/hp-t14/inputs/Dockerfile builder/hardware/hp-t14/inputs
mkdir -p build/firmware-check
docker run --rm -v "$PWD/builder/hardware/hp-t14:/hardware:ro" \
  -v "$PWD/build/firmware-check:/work" omarchy-firmware-builder:local --work-dir /work
```

`fetch-firmware.py --work-dir DIR` creates `DIR/firmware` only after every selected
file passes the checked-in manifests. Downloads are verified again before reuse.
`prepare-packages.py --work-dir DIR` requires those verified files and the pinned
ALSA UCM source contents supplied by `alsa-ucm-conf`; it creates `DIR/hardware`.
The normal Snapdragon builder runs both steps automatically. Vendor installers are extracted
as data, never executed. No Qualcomm SDK or QNN runtime is bundled.

## Hardware status

Both boards clean-installed the September 21 combined image with kernel 7.2.6-1.
That image predates the clean-checkout launcher above; physical boot of an ISO
assembled by the new launcher remains untested.
Speakers work on both. HP speech capture is owner-confirmed with one active PCM
channel; T14 microphone and media keys work. Bluetooth headphone playback works
on both. Automatic reconnection remains incomplete.

**Earlier T14 regression:** blocking Bluetooth dropped the Wi-Fi PCIe link. The
isolated test captured Wi-Fi removal and kernel waits. A warm reboot left Wi-Fi
absent; power-off/start restored it. HP radio toggles work independently. The
current T14 candidate adds the missing Wi-Fi consumer to the shared PMU;
one tested Bluetooth off/on cycle preserved Wi-Fi. This is not full radio
acceptance. A separate LDAC-associated freeze/reset was reproduced in earlier
testing; the owner later reported the four-minute reset absent on the radio
build. Reboot, toggle, codec and resume coverage remain follow-ups.

RGB cameras now pass capture and owner preview as detailed below. cDSP/NPU,
suspend and battery validation remain open; HP function keys are deferred. The
pull request records physical results and remaining gaps;
hardware investigations can continue in a Dragon discussion.

The command above is the maintained build path.

## RGB camera support

The camera integration is pinned to Dragon's Arch Linux ARM kernel **7.2.6-1**.
It compiles shared X1E80100 camera blocks once, applies separate board overlays,
and uses the existing UKI hardware-selection and installed-kernel update paths.
T14 uses the kernel's OV02C10 driver; HP includes the attributed GPL-2.0
[OV05C10 sensor module](hp-camera-package/README.md). Kernel and DTB pins fail
closed so a rolling kernel update requires explicit review.

| Board | September 24 physical result | Remaining acceptance |
| --- | --- | --- |
| ThinkPad T14s Gen 6 | Corrected ISO installs and boots; normal-user 1920x1092 processed capture and 720p PipeWire capture pass; owner confirms a great live picture. | First PipeWire capture timed out, while later default and alternate buffer-pool runs passed. Cold first-use reliability, sensor crop API, calibration/helper support and broader application tests remain. |
| HP EliteBook Ultra G1q | Camera ISO installs and boots; raw and 2880x1808 processed capture pass; 720p PipeWire and owner-visible preview pass. | Access rule tested locally on the preceding camera install. Fresh installation of the latest combined ISO, repeated cold-start capture and sensor calibration/helper support remain. |

The shared early package **0.3-2** grants the active local user access to the
system DMA heap through udev/logind. It leaves CMA heaps private; normal-user
software-ISP output buffers no longer exhaust the small CMA pool.

The first T14 camera overlay accidentally added an unused LDO7 to PMIC C, whose
PM8550VE provider only supports LDO1–3. The corrected **0.1-2** camera package
removes that entry and preserves all existing properties from the working radio
tree. A build check rejects unsupported PM8550VE/PM8010 regulator children.
Its install hook accepts the reviewed base, radio and faulty camera trees for
migration and leaves unknown kernel trees untouched.

The corrected combined ISO was assembled incrementally from the existing camera
build, with native `ukify` and SquashFS compression. All UKI section payloads
except the T14 DTB were preserved; the live camera-access package and offline
T14 camera package were updated. Boot layout and final ISO payload checks passed,
as did the shell checks and 124 Python tests. The physical T14 result confirms
this candidate; it does not establish that a new rolling, from-scratch build
will reproduce the same package set.

## Validation of the clean-input workflow

Validated public downloads in a fresh native container against both archive and
final payload hashes. Built six hardware/support packages plus pinned Dragon
runtime and settings in fresh ARM containers; ARM package-content checks passed.
Reproduced the base/patched T14 DTB hashes. The 52 selected unit tests, BusyBox
boot-hook test and both upstream helper-recipe tests passed.

A first full clean build also completed the pinned Neovim source package. It
stopped at offline dependency resolution: the staged ARM pacman configuration
omitted Arch Linux ARM's `[alarm]` repository, which contains `libpisp` for
`libcamera`. The builder now includes ARM's standard `[alarm]` and `[aur]`
repositories in that disposable online config; an ARM pacman sync resolved
`libpisp 1.5.0-1` from `[alarm]`. A second full build was paused before ISO
assembly. A completed clean ISO and physical boot remain acceptance work.

Vendor binaries are fetched at build time and are absent from Git. Distribution
of an ISO containing extracted HP/Lenovo firmware requires a separate review of
their redistribution terms.
