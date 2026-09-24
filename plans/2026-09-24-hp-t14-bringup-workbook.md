# September 24, 2026 — HP/T14 bring-up workbook

## Objective and current baseline

Make the ThinkPad T14s Gen 6 a reliable Omarchy Snapdragon laptop, retain the
HP EliteBook gains, and prepare focused contributions through Dragon's existing
kernel, hardware-package and ISO build methods. Bluetooth codec experiments
are one investigation within that objective, not the acceptance criterion for
the laptop. The owner specifically reports keyboard backlight working outside
Linux while the Omarchy OSD responds without changing the light inside Linux.

This is the current overall work queue. The [September 21 workbook](2026-09-21-hp-t14-workbook.md)
retains earlier physical results; the [September 24 radio workbook](2026-09-24-t14-radio-workbook.md)
contains today's playback evidence and its limits. The dated gap inventories
remain historical snapshots, not current feature status.

Owner priority for this pass: **P1 camera, P2 NPU, P3 keyboard lighting**, on
both boards where the hardware supports it. HP function-key lighting remains
deferred at the owner's request. Camera work can proceed independently of radio
crash analysis, but a new ISO needs a coherent board candidate and a separate
physical-boot acceptance pass.

Fetched ISO `origin/dragon` before review: still
`4b5b36d519577fe86e8d184ac22a62447027919c`, already included in the clean radio
worktree. No newer ISO changes to integrate. This does not imply that all kernel
or runtime upstreams are unchanged. The camera changes are in isolated
worktrees. The first camera ISO black-screened on T14; the corrected September 24
camera-lcd-fix ISO now installs and boots on the physical T14. Preserve the
working radio ISO and build caches.

## Capability ledger

| Area | Established result | Remaining acceptance / next work |
| --- | --- | --- |
| T14 live USB, installation and encrypted installed boot | Owner confirms camera-lcd-fix ISO installs and boots; SSH confirms corrected DTB and camera package 0.1-2. | Initial display regression resolved in this install test; repeated cold boot, update and rollback checks remain. |
| HP boot/install | Owner installed the September 24 camera image; SSH confirms an encrypted installed boot with the expected HP camera DTB. | Keep reboot, update and rollback checks open. |
| Internal speakers, T14 mic/media keys, HP speech capture | Owner-confirmed successes recorded in the earlier workbook; T14 speaker control also passed today. | Retain as regression checks, not unsolved enumeration problems. HP capture's second channel remains silent despite usable speech. |
| T14 Wi-Fi / Bluetooth power ownership | Candidate binds Wi-Fi to the shared PMU; one Bluetooth off/on cycle preserved Wi-Fi. | Full software-reboot, Wi-Fi-toggle, cold-start and resume acceptance still open. |
| T14 Bluetooth audio | Same Nothing Ear passed SBC for 6:23; LDAC then froze/restarted the laptop. | Root cause unresolved. No default codec restriction or further crash trial added during this review. |
| T14 keyboard lighting | Physical pre-OS operation reported; Linux key/OSD path responds. Normal privileged LED writes do not change reported brightness. | Trace identifies a driver/EC interaction gap; obtain this firmware's intended control sequence before changing the driver. |
| Suspend, wake, charge thresholds and battery | Interfaces exist; previous logs contain suspend/resume and a USB-C retimer warning. | Existence of events is not a measured power/resume pass. Keep both boards' idle, sleep-drain, charging and peripheral-restoration checks open. |
| T14 RGB camera | Corrected image enumerates OV02C10; normal-user full-resolution processed capture and 720p PipeWire capture pass. Packaged DMA-heap access works on the fresh install. | Owner confirms a great live picture. First PipeWire capture timed out, subsequent runs passed; cold first-use reliability, sensor crop API and calibration/helpers remain. |
| HP RGB camera | New image enumerates OV05C10; raw capture, full-resolution processed capture and 720p PipeWire capture pass. A narrow DMA-heap access rule is applied and packaged. | Owner confirms a good live picture; reboot acceptance remains and sensor calibration/helpers are still missing. |
| cDSP / NPU, both boards | Firmware runs, but no cDSP FastRPC device exists. | Today's T14 retry directly captures channel-open timeout. Restore transport before calculator/validator/HTP inference. |
| T14 other input, GPU, USB/docks, external displays, TPM | Mostly enumeration or earlier limited checks. | TrackPoint hardware condition, full controls, real rendering, per-port use and security capabilities need their own checks. |
| HP Fn keys / keyboard lighting | Owner explicitly deferred the deeper issue. | Remains deferred; do not conflate it with the T14 EC driver. |

## T14 keyboard backlight: narrowed below the OSD

System: BIOS `N42ET92W (2.22 )`, dated 2025-06-27; kernel `7.2.6-1-aarch64-ARCH`;
boot `13937f00-1a55-492a-b13f-e913a4c849cf`. The in-tree
`lenovo_thinkpad_t14s` module binds EC `4-0028` and exposes
`platform::kbd_backlight`, range 0–2. The owner's pre-OS result is positive
hardware evidence; the earlier disconnected TrackPoint must not be treated as
an established explanation for this lighting failure.

Read the installed Omarchy keyboard-brightness command and bindings. Fn+Space's
mapped action cycles this LED. The script displays the *requested* percentage;
it neither reads the resulting hardware level nor checks the brightness command
before showing the OSD. SSH-session permissions are a separate concern and do
not explain the following privileged failure.

Wrote levels 1 and 2 through the normal LED brightness sysfs interface. Both
writes were accepted, but immediate and one-second readbacks remained 0.
Restored the original level 0. A further single level-2 write used temporary,
filtered I2C/regmap tracing to observe what the existing driver actually did:

| Operation | Captured result |
| --- | --- |
| Read EC register `0x0d` | `0x01`; brightness bits 7:6 decode to zero. |
| Write brightness 2 to `0x0d` | I2C payload `03 0d 00 01 81`, transaction return 1. |
| Read / write EC register `0xe1` | Initially `0x00`; write payload `03 e1 00 01 08`, transaction return 1. |
| Read brightness after 300 ms | Register `0x0d` still `0x01`, reporting brightness zero. |
| Restore level 0 | Driver reads `0xe1=0x08`, then writes it back to `0x00`; final brightness zero. |

This confirms communication with the EC and persistence of the second control
field. It does not prove why the first field fails to retain the requested
brightness: firmware semantics, required ordering/state or an EC quirk still
need evidence. It is not solved by adding another keybinding or sudo wrapper.
The tested LED writes are asynchronous kernel operations, so write acceptance
alone is not hardware success; the delayed trace/readbacks are the evidence.

The matched 7.2.6 EC source is byte-identical to the upstream master file fetched
today. Existing access-delay and suspend-handler fixes are already present.
The [driver author describes deriving the protocol from ACPI DSDT](https://patchew.org/linux/20250831-thinkpad-t14s-ec-v1-0-6e06a07afe0f@collabora.com/20250831-thinkpad-t14s-ec-v1-2-6e06a07afe0f@collabora.com/).
Next: obtain the matching firmware's ACPI control methods and compare its
brightness/OS-state sequence with `t14s_kbd_bl_set`, then make a focused driver
candidate. The DT-booted system does not expose DSDT in ACPI sysfs. A bounded
read of its EFI-advertised ACPI pointer through `/dev/mem` was denied with EPERM;
no protections were relaxed and no firmware table was recovered. Use an offline
firmware/table source or later recovery environment, not speculative EC writes.

Only normal LED interface writes were used. No direct EC register writes,
bus scans, driver replacement or controller reset occurred. The temporary trace
instance was disabled and removed; original brightness is restored.

## cDSP / NPU: channel-open timeout identified

Both machines still lack `/dev/fastrpc-cdsp` and `/dev/fastrpc-cdsp-secure`.
HP retains the cDSP QRTR and FastRPC boot failures. On the T14's current boot,
**QRTR is bound on cDSP**, while FastRPC remains unbound. This is more specific
than the earlier blanket description that both channels always fail.

Reviewed the exact source path before one T14 probe retry:
`rpmsg_dev_probe` → `rpmsg_create_ept` → `qcom_glink_create_ept` →
`qcom_glink_create_remote`. The [RPMsg core](https://github.com/torvalds/linux/blob/v7.2/drivers/rpmsg/rpmsg_core.c)
reports `-ENOMEM` whenever endpoint creation returns NULL; the
[GLINK implementation](https://github.com/torvalds/linux/blob/v7.2/drivers/rpmsg/qcom_glink_native.c)
can return NULL after an open-ack timeout. Thus the printed `-12` is not itself
evidence of memory exhaustion.

Traced one normal `drivers_probe` request targeting only the already-unbound
cDSP FastRPC RPMsg device, with a 20-second command cap and a small temporary
trace instance filtered to cDSP. Trace sequence, monotonic seconds:

```text
945.576144  TX OPEN_ACK  fastrpcglink-apps-dsp [2/3]
945.576150  TX OPEN      fastrpcglink-apps-dsp [3/3]
950.750287  TX CLOSE     fastrpcglink-apps-dsp [3/3]
```

No received open acknowledgment appears. The probe takes 5.174 seconds,
logs the endpoint error again, leaves the device unbound and creates no new
FastRPC device nodes. This identifies the failed handshake in this retry;
it does not establish whether firmware failed to respond or Linux failed to
process the response. Retrying after startup did not resolve it.

The installed HP and T14 cDSP firmware pairs are byte-identical to their own
Ubuntu 7.0 pairs that passed HTP inference; firmware mismatch is not the
current explanation. A source comparison found no change in the cDSP GLINK
open handshake or Hamoa channel definition from upstream 7.0 to local 7.2
that explains this timeout. The HP's cDSP QRTR channel also fails, while the
T14's binds, so the boards are not identical transport cases.

Next: capture an early GLINK trace after a *full power-off* boot, then compare
Ubuntu vendor kernel patches with Dragon's kernel. Account for possible state
surviving warm reset. Do not start by changing CMA size, installing QNN
libraries or replacing board firmware at random.
No DSP restart, ADSP unbind, inference, firmware write or package change was
performed. Temporary tracing is removed and Wi-Fi/boot identity are unchanged.

After transport is restored, retain the original validation ladder on each
board: calculator `499500`/`999`, platform validator, explicit HTP backend ID 6
ReLU `[0,0,0,3]`, cleanup and repeat after reboot. Those are still required;
creating a device node will not count as an NPU pass.

## Cameras: reuse upstream infrastructure and separate board patches

The 7.2.6 source has X1E80100 CAMSS resources, camera-clock driver, CCI and
OV02C10 support. Its Hamoa/T14 DT lacks the shared camera block declarations
and board sensor graph used by the validated 7.0 tree. An overlay that only
enables an OV02C10 endpoint would therefore be incomplete.

The [September 17 upstream v7 series](https://lists.openwall.net/linux-kernel/2026/09/17/1648)
adds shared CCI/CAMSS declarations and separate T14 PM8010 camera-regulator and
OV02C10/CSIPHY4 patches. It depends on the matching CSI2 PHY work. The historical
working tree uses the older integrated PHY description; mixing its numeric
phandles or graph shape with newer standalone-PHY bindings is inappropriate.

Dragon's exact 7.2.6 CAMSS driver uses the integrated CSIPHY ABI. Its
`hamoa.dtsi` has no CAMCC, CCI or CAMSS nodes, although the drivers are modules.
The [March 2025 v6 series](https://patchew.org/linux/20250314-b4-linux-next-25-03-13-dtsi-x1e80100-camss-v6-0-edcb2cfc3122@linaro.org/)
describes this ABI, but targets the older `x1e80100.dtsi` filename. The T14
candidate in `builder/hardware/hp-t14/x1e80100-camera.dtso` carries shared SoC
nodes into the current tree; `t14-camera.dtso` adds the later upstream
OV02C10/PM8010 board wiring and the integrated-PHY lane map seen in the
successful Ubuntu 7.0 tree. It
compiles and overlays on Dragon's exact pinned 7.2.6 radio DTB; final SHA256:
`93ffd63948e6ed79a2c459ab1a5079d848f06d0437352a978ee8322a0c3abf37`.
This is DT/source validation only; no camera node or frames have been observed
on a machine booted with this candidate yet.

The September 24 camera ISO built successfully with both camera DTB hash
checks passing, then the owner reported a T14 black screen before the Omarchy
logo. The GRUB menu and kernel boot are visible, including the penguin icons;
the screen then goes black during later boot. The exact failing initramfs or
userspace step is not yet established. The September 23 radio ISO remains the
known booting baseline.
Extracted and compared the live EFI images: the kernel, hardware-ID table and
30 of 32 device-tree sections are byte-identical. Only the T14 and HP board
DTB sections changed. The
GRUB EFI binary differs in just 12 bytes, all in two copies of the ISO UUID
filename; the new ISO contains that matching UUID file.
The T14 board DT newly registers several PM8010 regulators, including rails
with no declared consumer. Linux may disable unclaimed regulators at boot;
this could account for display loss as boot progresses but remains a hypothesis.
The requested discriminating boot test is the temporary
`regulator_ignore_unused` kernel argument. HP subsequently installed and booted
this camera ISO; its capture results are recorded below. A build alone is not
camera acceptance.

LCD regression audit, prompted by the owner's earlier display fix: the
September 12 fix made the display dependency chain available before root
unlock, including panel/backlight, QFPROM, hardware spinlock, QRTR and bridge
drivers. The working radio ISO and failing camera ISO have identical initramfs
file lists. Comparing file contents and modes across all 3,688 CPIO entries
finds exactly one difference: `etc/os-release`. The display modules and GPU
firmware therefore have not been dropped or replaced. In this kernel,
`pwm_bl`, `qcom_hwspinlock` and `nvmem_qfprom` are built in; panel-edp, LPG,
SPMI SDAM, QRTR, PS883x, SBU mux and bridge modules are present in the archive.

The embedded T14 DT preserves all 6,485 existing properties without removal
or modification. All 177 display-subsystem properties and seven backlight
properties are identical, as is `lenovo,thinkpad-t14s-lcd` compatibility.
This rules out simply losing the earlier LCD content. It does not rule out
the new camera clock, regulator or probe dependencies disrupting display
initialization. In particular, CAMCC/CCI modules already in the initramfs can
now probe the newly added nodes before switching to the live root. No logs yet
prove which new dependency or resource causes the blank screen.

The owner could not locate the GRUB chainloader line. A diagnostic copy was
made with only `regulator_ignore_unused` appended to the HP/ThinkPad boot
entry: `~/ISOs/omarchy-dragon-hp-t14-camera-regulator-test-2026.09.24-aarch64.iso`,
SHA256 `0d393dc7a268b8a57152cfc6d410dedf02c4e9e1febd96d79df34014915702b6`.
The bootloader and live EFI payload remain byte-identical to the camera ISO;
the diagnostic boot result is pending. This is not a demonstrated fix.

The HP board overlay now uses that same shared X1E SoC block and supplies only
HP's PM8010 LDO3_M, GPIO100/237/50, OV05C10 at CCI1 bus 1 address `0x10`, and
CSI4 graph. The GPL OV05C10 module builds against pinned 7.2.6 headers with
matching vermagic and OF alias. The generated HP DTB SHA256 is
`090e8e46693c61bf0236df43060db55ac6549d15ee2cd3c234c8de57c4b4e962`.
The package and live image retain exact-hash guards. This also needs a physical
reboot/preview acceptance pass after the initial successful capture tests below.

### HP installed camera capture: September 24

HP `10.0.0.42`, boot `ae6ddec3-63a4-402d-a2f6-f2591d2c28e2`, runs kernel
`7.2.6-1-aarch64-ARCH` and camera package `0.1.0-1`. The installed DTB matches
`090e8e46693c61bf0236df43060db55ac6549d15ee2cd3c234c8de57c4b4e962`.
OV05C10 binds at `5-0010`; CAMSS exposes `/dev/media0` and the CSI4 sensor
link. libcamera 0.7.2 recognizes an internal front camera.

Initial normal-user enumeration reports no accessible DMA-buf provider.
Root capture at full processed resolution fails allocating a third output
buffer from the 128 MiB CMA pool. This is a demonstrated allocation limit in
this test, not evidence for changing NPU memory reservations. Raw capture
works: ten `2800x1576-SGRBG10_CSI2P` frames at about 26 fps. Root 720p
processed capture also works.

Granting the desktop user access to `/dev/dma_heap/system` alone permits
full-resolution processed buffers without consuming the restricted CMA heaps.
A temporary ACL test captured 30 `2880x1808-ABGR8888` frames at about 30 fps.
After replacing that ACL with the persistent udev rule, ten more full-resolution
frames passed as `bobp`. No captured image files were saved.

The shared early-hardware package is now `0.3-2` and installs
`70-omarchy-camera-dma-heap.rules`: match the `system` DMA heap and add
`uaccess`, granting the active local desktop user access through logind.
The two CMA heaps remain root-only. The HP test copy is in
`/etc/udev/rules.d/70-omarchy-camera-dma-heap.rules`; remove that identical
local override after the updated package is installed. The package build,
udev rule verifier and targeted rule reload passed. No boot configuration or
CMA reservation was changed.

WirePlumber was restarted once to discard its pre-fix software-ISP state;
there were no active audio streams. GStreamer through the resulting PipeWire
camera source delivered 30 `1280x720` frames and exited with EOS/status 0.
A 90-second PipeWire/Wayland preview was opened for the owner; the owner confirmed a live picture with correct orientation and usable colours. libcamera still uses uncalibrated OV05C10 defaults
and reports no sensor helper/static delays. Capture success does not establish
calibrated exposure/colour or application/reboot acceptance.

Earlier planning (superseded by the camera build and HP results above):
select and pin a consistent driver/binding/DT set against Dragon's kernel;
prepare the shared SoC portion once, then separate T14 and HP board patches.
Check CAMCC power-domain requirements, supplies, clocks, lane graph and privacy
LED. Address normal-user DMA-heap access after enumeration; current heaps are
root-only, but permissions cannot create missing camera hardware nodes.
Acceptance remains direct frame capture, PipeWire frames, owner-visible preview
and reboot repeat. HP OV05C10 remains a distinct sensor-driver task.

## Radio: preserve evidence and audit applicable fixes

The old Bluetooth-off → Wi-Fi PCIe-loss sequence and today's LDAC-associated
whole-system reset are separate observations. Shared Wi-Fi PMU ownership
improved the former in one test; it is not full radio acceptance.

Same-earbud codec comparison is a strong reproducer, not proof that the LDAC
encoder itself is faulty. Today's measured HCI payload is 677 kb/s for LDAC
versus 280.3 kb/s for SBC. The DT requests a 3.2 Mbaud UART, so payload rate alone
does not demonstrate UART saturation. Burst handling, DMA/flow control, in-band
sleep, controller firmware and radio coexistence remain candidates.

Source audit avoids two speculative backports:

- The [GENI TX DMA flush correction](https://github.com/torvalds/linux/commit/e3c04834ae1a)
  is already present in the matched 7.2.6 source, including its DMA flush callback.
- The [recent QCA closed-port fix](https://github.com/torvalds/linux/commit/4e93c65f8782)
  targets the WCN399x power-off branch, not the WCN7850 steady-playback path.

T14 loads `hmtbtfw20.tlv`, build `BTFW.HAMILTON.2.0.1-00349-WOS_PATCHZ-2`, and
`hmtnv20.b112` (a packaged symlink to `hmtnv20.b10f`). Their hashes are retained.
HP's DT selects the WCN6855 setup path, whose patch lookups fail, despite the
same reported controller product/SoC IDs. Therefore HP is not automatically an
equivalent Bluetooth firmware/codec control. Verify firmware provenance and
board NVM selection before drawing a cross-board conclusion; no payloads were
changed. No further LDAC playback was initiated in this review.

Next: compare the exact old/current UART, QCA and firmware paths, and prepare a
way to retain crash evidence that does not rely solely on Wi-Fi before another
deliberate reproducer. Current EFI pstore is disabled. A generic upgrade, forced
power-on policy or permanent SBC restriction is not yet a demonstrated fix.

## Work order and integration gate

1. **P1 cameras:** complete compatible shared CAMCC/CCI/CAMSS definitions and
   separate T14 OV02C10 and HP OV05C10 board/sensor changes. Boot a candidate
   and prove media enumeration, frames, PipeWire and preview on each board.
2. **P2 NPU:** capture the cDSP GLINK handshake from a cold boot and compare
   Ubuntu vendor deltas before changing transport code. Once FastRPC binds,
   repeat calculator, platform validator and explicit HTP inference on both.
3. **P3 keyboard lighting:** compare this T14 BIOS's ACPI EC method to the
   driver; its EC brightness register `0x0d` does not retain the requested
   level. The OSD is not proof of light. HP has no Linux backlight LED class
   and was dark pre-OS in earlier testing; keep its Fn work deferred.
4. Preserve radio, audio, install and suspend/battery checks as regression
   gates. Keep the LDAC-associated hard reset separate from these gaps, and
   each kernel/DT contribution reviewable separately from ISO packaging.

Build at the earliest coherent change requiring physical boot validation, not
after an arbitrary number of unrelated patches. Reuse the saved package/Neovim
cache; preserve Dragon's normal UKI and build contracts. The camera candidate
ISO is at `~/ISOs/omarchy-dragon-hp-t14-camera-2026.09.24-aarch64.iso`, SHA256
`f74d5ffba6e06ca9ffa33840bb437f8a4054aa21ebd9e6c70dc675bc11c3973e`.
Its T14 boot shows kernel penguins/output then loses the display before the
Omarchy logo; it is not a usable acceptance image.

The launcher now mounts the persistent Snapdragon `downloads`, `firmware`, and
`kernel` cache directories under
`~/.cache/omarchy/iso_edge/aarch64/snapdragon/hardware` into the build container.
The previous verified vendor downloads, extracted firmware and kernel package
were copied there from the September 23 snapshot using filesystem reflinks.
The fetch script still checks their pinned hashes before reuse; a fresh build
does not need to re-download the 4.15 GB Ubuntu ISO or rebuild the extracted
firmware unless a source pin changes.

Evidence: `build/t14-gap-review-20260924/`, with checksums. These local logs are
not a public payload. The camera overlay and its build integration are staged
in an isolated worktree. HP runs the candidate with the tested camera-access
rule; T14 camera-image boot remains a regression.


## T14 camera boot regression: invalid PMIC child

The owner tested the `camera-regulator-test` ISO: it still goes black. That
parameter does not address the concrete DT error found afterward.

The camera board overlay added an unused `vreg_l7b_2p8` at the hardcoded
`/soc@0/rsc@17500000/regulators-1/ldo7`. In the pinned Dragon kernel's T14
DT, `regulators-1` is PMIC C, compatible `qcom,pm8550ve-rpmh-regulators`.
The [RPMh driver](https://github.com/torvalds/linux/blob/master/drivers/regulator/qcom-rpmh-regulator.c) permits LDO1–3 for this PMIC, so LDO7 aborts the provider probe with EINVAL.
This also prevents registering S4C and L1C–L3C, affecting downstream
regulators and USB PHYs. This is a definite DT defect and a strong boot
regression candidate; physical T14 boot remains the confirmation gate.
The exact display failure chain has not been measured on the black-screen boot.

Removed that unused addition. OV02C10 uses L7M/L2M/L4M and needs no L7B.
The corrected T14 DTB is
`f240d5d824800dde1c731cb660fa0d164dfa68fccfafc8630474f9bf6a6697b0`.
The camera package is 0.1-2; its install hook can migrate the known faulty
0.1-1 camera tree as well as the reviewed base/radio trees. Unknown kernel
DTBs remain untouched. The HP DTB is unchanged. The shared early package
0.3-2 carries the owner-validated camera DMA heap access rule.

The previous comparison correctly found no changed existing display properties,
but it missed that adding an invalid child can disable an existing provider.
The builder now checks child names for the PM8550VE and PM8010 regulator
providers in each merged camera tree before packaging. This is a targeted
regression guard, not a substitute for full DT binding validation.

Corrected ISO assembled using native ukify and squashfs-tools from the existing
camera image. All UKI payloads are unchanged except the T14 DTB; the shared
early package and offline T14 camera package are updated. The offline database
contains all 1121 expected packages. The known faulty camera tree migrates,
while unknown trees and corrupted payloads are protected. Shell checks and
124 Python tests pass. ISO bootloader, GRUB configuration and all replaced
files passed extraction/checksum verification; EFI/GPT boot layout retained.

Artifact: `/home/bobp/ISOs/omarchy-dragon-hp-t14-camera-lcd-fix-2026.09.24-aarch64.iso`

SHA256: `66951b095e0a6cc4e153d11f52e67c3074cec773aff6e00dce4ae832a34f8cbe`

The source patch, new sources, updated packages, extracted root, compressed
root and build scripts remain under `build/camera-lcd-fix-20260924/`.
This is an incremental regression candidate, not a new from-scratch build.
T14 boot/install and camera capture are pending owner testing.
Stop here for the owner to flash and test.


## Physical T14 acceptance after camera-lcd-fix install

September 24: owner confirms the corrected ISO installs and boots. SSH at
`10.0.0.53` confirms kernel `7.2.6-1-aarch64-ARCH`, camera package `0.1-2`,
shared early package `0.3-2`, and the corrected DTB hash recorded above.
Boot ID: `f0a5fc74-c2bb-4a6f-8ca0-0b8bd9b886e8`. Initial journal wall-clock
entries precede time synchronization; correlate this test by boot ID/uptime.
No unknown-regulator messages or deferred devices remain in the inspected boot.

OV02C10 binds at `7-0036`, creates the media/video devices, and libcamera
recognizes the internal front camera. The normal desktop user has access to
only the system DMA heap through the packaged rule; no manual permission or
configuration changes were needed on this install. `cam -c 1 --capture=30`
delivered 30 `1920x1092-ABGR8888` frames, 8,386,560 bytes per frame, generally
30 fps after one approximately 0.9-second startup pause. No images were saved.

First GStreamer/PipeWire capture at 720p timed out after 20 seconds without
reaching its requested 30-frame EOS; an uncapped follow-up reported target
not found. Neither is counted as a pass. A ten-frame run with buffer pooling
disabled succeeded. A controlled follow-up at 720p/30 frames then passed with
both default buffer pooling (1.33 seconds) and pooling disabled (1.25 seconds).
Thus disabling buffer pooling is not established as a necessary fix, and no
persistent workaround was added. First-use reliability remains open.

A normal PipeWire/Wayland preview was opened with a 90-second automatic stop.
The owner reports the live picture looks great, confirming usable picture,
orientation and colours. The preview was stopped after that confirmation. Sensor crop/selection ioctl warnings,
missing static delays/helper and uncalibrated defaults remain follow-ups.
Evidence: `build/t14-camera-acceptance-20260924/`.

### HP USB copy-speed observation

Owner measured roughly 33 MB/s copying the ISO on HP and 233 MB/s on T14
with the same stick. Owner confirms the HP rate appears **after Linux starts**
while copying the image to RAM, rather than during firmware loading.
On reinsertion in the running HP, the SanDisk 3.2Gen1 appears at `4-1`,
negotiates **5000 Mb/s**, and uses UAS. A bounded read-only direct-I/O test
(`dd if=/dev/sda of=/dev/null bs=4M count=128 iflag=direct`) read 512 MiB in
2.489 seconds: **216 MB/s**. Nothing was written to the stick.

The installed HP USB path supports normal USB 3 throughput. The prior live
boot's negotiated speed was not captured; a 33 MB/s copy alone does not prove
USB 2 negotiation. Early PHY/controller readiness, cold enumeration and the
live-copy path remain hypotheses. Next useful evidence is USB speed/topology
and kernel enumeration logs during the slow live boot; reinstalling is not
required. Keep this separate from the camera regression.

HP remains on the earlier camera install (early package `0.3-1` plus the
previously tested local camera access rule), with its owner-accepted camera.
Do not count it as a fresh install test of the latest `0.3-2` package.
