# September 21, 2026 — HP and T14 Dragon workbook

## Baseline

Both machines install and boot Dragon's `linux-aarch64 7.2.6-1` from encrypted
internal storage. Wi-Fi and internal displays work on both. The HP speaker
was physically heard; the T14 has exposed audio routes but no audible test on
this installation. The T14 needed early DSP startup to find its installer USB.
The successful A/B image changed only that boot policy; the normal Dragon
live menu still blacklists the DSP driver.

### Owner test update — shared DSP-enabled ISO

`omarchy-dragon-t14-dsp-test-2026.09.21-aarch64.iso` now reaches the installer
on **both HP and T14**, confirmed by the owner. The T14 also completed a fresh
installation and booted its installed root. The HP was tested only through
live installer startup on this image; its earlier installed-system pass remains
separate. Another HP reinstall is unnecessary for this isolated live-policy test.

Both show the deliberately verbose diagnostic boot. Restore normal splash
presentation in the integrated candidate while retaining an optional diagnostic
entry. The shared live-boot checkpoint is passed; repeated cold boot, per-port
coverage, update/rollback and board-aware production integration remain open.

Source inventories: [HP](../HP_Elitebook_Gaps.md),
[T14](../T14s_Gaps.md), and the [USB A/B investigation](../experiments/hp-thinkpad/t14-usb-investigation.md).
The earlier [bring-up plan](hp-thinkpad-dragon-bringup.md) records the original
approach; these post-install findings replace its pre-install assumptions.
The old earlier prototype camera and NPU passes remain useful baselines for kernel 7.0,
not Dragon passes.

### Owner test update — sound and controls

The owner hears T14 playback, sees its mic meter respond, and confirms its media
keys work. HP playback works, but its internal-mic meter does not respond. A
bounded PCM comparison confirmed the HP default route is silent while the T14
captures music. [HP mic investigation](../experiments/hp-thinkpad/hp-mic-investigation.md)
records an HP-only UCM mux candidate that produced sustained PipeWire samples
with music nearby. One capture channel remains silent; owner listening and
installed-image validation are pending. The trial files were restored on HP.

### T14s Bluetooth trial and ISO checkpoint

The T14s has no HCI because Dragon's current board tree omits the WCN7850
power node and leaves its Bluetooth UART disabled. The working 7.0 tree has
both. A T14-only [device-tree trial](../experiments/hp-thinkpad/t14-bluetooth-investigation.md)
was booted by the owner. Firmware setup completed, the controller is powered,
nearby devices appear, and Wi-Fi remains connected. The original boot entry
remains the default. This cleared the owner's hold on the combined ISO build;
the clean-install results follow below.

### Clean-install check — combined ISO

The owner completed fresh T14 and HP installs from the combined HP/T14 ISO.
Both boot the normal Omarchy entry on kernel `7.2.6-1` with Wi-Fi connected.
On T14, the Bluetooth package is installed, the active tree contains the
WCN7850 PMU and enabled UART14 Bluetooth node, QCA firmware setup completes,
BlueZ is active, and a bounded scan discovers nearby devices. A three-second
PipeWire microphone capture produced nonzero samples on both channels (RMS
1565 and 1614). The owner heard speaker playback and paired Nothing Ear (3)
headphones. Pairing alone left the headphones disconnected and music routed to
the speakers. A manual BlueZ connection exposed an A2DP sink; selecting it as
the default and moving the active stream produced audible headphone playback,
confirmed by the owner. Automatic reconnection and routing after a reboot
remain untested.

On HP, the `0.3-1` hardware package and DMIC2 UCM route are installed.
Speaker and internal-mic nodes appear. A three-second PipeWire capture produced
128,158 nonzero samples on the active channel (RMS 350); the other channel
remained exactly zero. The owner confirms the internal-mic meter moves while
speaking and a short recording sounds clear, so usable HP speech capture now
passes despite the silent second channel. The owner also heard HP speaker
playback. The HP Bluetooth controller and Wi-Fi also enumerate; optional
Qualcomm Bluetooth firmware lookup warnings remain in the kernel log. A paired
Nothing Ear (3) headset was visible during a subsequent HP check. Its first
connection did not resolve services or expose a PipeWire audio sink, and one
reconnect attempt timed out. It then connected and began playing, confirmed by
the owner. BlueZ reported resolved services, PipeWire showed the active A2DP
profile, and the headphone sink was the default with the mpv stream routed to
it. After an HP reboot, the headphones did **not** reconnect automatically;
they connected later and playback resumed. Automatic reconnect at boot
therefore remains an open quality-of-life gap.

The first T14 software reboot after this Bluetooth/audio test was slow, with a
visible `qmi failed to send wlan mode off` message, but eventually completed
without a forced power cycle. In the previous boot's journal, NetworkManager
and `wpa_supplicant` both timed out during shutdown and remained running after
SIGKILL; `ath12k_wifi7_pci` repeatedly reported pending transmit and management
packets. The last persisted entry is at 18:07:16. The next boot's clock was
corrected by NTP; its actual start was about 18:11:46, leaving roughly 4.5
minutes after the old journal stopped that have no persisted trace. The new
boot has working Wi-Fi and no failed systemd units. The visible QMI line was
not saved in the previous journal, so its exact error code and relationship to
the late shutdown delay remain unconfirmed. No Bluetooth device was connected
when the owner initiated a second T14 reboot. SSH dropped at 18:17:11 and
returned at 18:22:29 (about 5 minutes 18 seconds). The previous boot again shows both
NetworkManager and `wpa_supplicant` timing out and surviving SIGKILL, repeated
pending ath12k transmit and management packets, and a peer-key removal timeout
of `-110`. The previous journal ends at 18:17:28; after NTP corrected the new
boot's clock, its actual start was about 18:21:55, leaving another roughly
4.5-minute unlogged interval. Wi-Fi works after boot and no systemd units are
failed. A connected headset is therefore not required to reproduce the slow
reboot; the Wi-Fi teardown path is the leading observed failure. This does not
yet distinguish the Wi-Fi driver/firmware from the board power-sequencing
interaction. HP, on the same kernel and WCN7850 driver/firmware, shut down its
NetworkManager and `wpa_supplicant` promptly in the observed reboot.
Read-only device-tree comparison found that HP declares `wifi@0` below its
PCIe port with WCN PMU supply links and exposes a Wi-Fi-to-PMU device link.
The installed T14 tree has the Bluetooth PMU but no Wi-Fi child or corresponding
device link. The upstream QCP WCN7850 tree has this Wi-Fi child. A separate
[`t14-bluetooth-wifi-pmu.dtso`](../experiments/hp-thinkpad/t14-bluetooth-wifi-pmu.dtso)
candidate adds these links to the T14 overlay; it compiles and applies against
the exact 7.2.6 base DTB, while the original overlay still reproduces the
shipped DTB hash. A T14-only trial UKI with this candidate was added through
`limine-entry-tool` as `Omarchy/t14-wifi-pmu-trial`. Its embedded kernel and
initramfs match the normal UKI byte for byte, and its embedded DTB matches the
candidate. `Omarchy/linux-aarch64` remains the explicit default, its UKI hash
matches the pre-trial value, and a copy of the prior Limine config is retained
at `/boot/limine.conf.before-wifi-pmu-trial`. The owner selected the PMU trial
and reported a complete freeze with no
keyboard response. The T14 did not answer ping or SSH. Treat this candidate as
**failed**; do not make it the default or include it in an ISO.
The owner forced the frozen machine off and booted the normal entry. The trial
left no separate journal boot or pstore record. Wi-Fi works on the normal tree.
The failed trial UKI and Limine entry were removed with `limine-entry-tool`;
the normal UKI and installed DTB retain their original hashes and
`Omarchy/linux-aarch64` remains the default. Do not ship the Wi-Fi PMU child.

Audit correction: this trial changed both the DT contents and UKI construction.
Normal boot used multiple `.dtbauto` sections; the trial used a single `.dtb`
section in a newly built UKI. Equal kernel/initramfs bytes do not isolate those
other changes. The failed image is rejected for deployment, but the freeze
alone does not prove the Wi-Fi PMU links are wrong. Any future comparison must
preserve the normal UKI selection mechanism and change only the target DT.

### Bounded T14 Wi-Fi disconnect test

One test ran on the normal image at 18:45:32. A transient systemd service
captured kernel messages and process stacks for about 80 seconds. A separate
one-shot timer requested reconnection after 40 seconds. `nmcli dev disconnect
wlan0` completed successfully before the first five-second sample; the recovery
request succeeded, with kernel association visible about 54 seconds into the
capture. Both transient services finished successfully and the timer is
inactive. No reboot, driver unload, or boot-image change was performed.

The test produced no new ath12k TX-flush, peer-key, or QMI failure. The
20-second blocked-task dump listed no blocked tasks; sampled NetworkManager
and supplicant stacks showed ordinary poll/select/futex waits. One display
worker was in D state at the 55-second snapshot, so this is specifically a
negative result for the Wi-Fi failure, not a claim that all tasks were always
unblocked. Normal Wi-Fi disconnection did not reproduce the shutdown failure.
Full service teardown, driver shutdown, and shared Bluetooth/Wi-Fi power
ordering remain untested by this operation. Stop here for this bounded pass.

Evidence: `build/hp-thinkpad/wifi-diagnostics/t14-wifi-bounded/` locally and
`/var/tmp/t14-wifi-bounded/` on the T14. The local directory includes the
capture script, kernel log, process stacks, and disconnect/reconnect results.

### Deferred HP Fn and keyboard lighting

HP Fn/media keys and keyboard lighting remain unresolved and are **deferred**.
The earlier HP investigation (historical hardware notes)
found an EC/WMI event path in firmware that the current DT boot does not expose
as a working hotkey device. HID captures showed ordinary F-key reports during
the tested combinations; changing the BIOS mode, issuing standard HID power-on,
and toggling the identified EC hotkey-enable bit did not restore media actions.
The event-delivery and lighting protocols are still unproven. Do not treat this
as a simple keybinding change, infer a broken EC, or make HP Fn a gate for the
next phase. Revisit it as a separate HP platform investigation when prioritized.

We prioritize by how much a gap interrupts normal laptop use. A detected
interface is not a functional pass. Record per-board kernel, DT, firmware,
test and result as **works**, **fails**, or **untested**.

## Phase 0 — Make boot repeatable

**Quality-of-life reason:** losing installer USB or visible disk unlock makes
every later fix hard to deploy or recover.

| Shared work | HP lane | T14 lane | Exit gate |
| --- | --- | --- | --- |
| Fetch upstream `dragon` before each new integration or build. Freeze the working ISO, package set, DT and boot arguments. | Supervised cold boot and visible LUKS unlock. | Supervised cold boot and visible LUKS unlock; retain the successful DSP-enabled A/B result. | Each board boots installed storage twice and returns over SSH. Kernel update and rollback stay untested until exercised. |
| Trace the early DSP versus USB interaction and encode the result through Dragon's existing board/boot methods. Preserve other machines' USB protection. | Shared candidate still reaches the installer and copies the root filesystem. | Shared candidate reaches the installer from the applicable USB ports; record any port limit. | One proposed image boots on both; stop for owner testing before promotion. |
| Close cheap functional unknowns without making changes. | Test USB data and the manual brightness control; HP Fn/media keys and keyboard lighting are deferred separately. | Check ordinary/Fn keys, touchpad and current TrackPoint hardware condition. | Each observation becomes a real pass/fail; deferred HP Fn is not a phase gate. |

Do not remove `modprobe.blacklist=qcom_q6v5_pas` globally based on the T14 test.
The kernel and DT remained constant in that A/B comparison, but the exact USB
power or mux mechanism has not yet been identified.

## Phase 1 — Sound, controls and Bluetooth

**Quality-of-life reason:** these affect calls, media, typing and peripherals
in ordinary sessions. Test exposed interfaces before editing them.

| Shared work | HP lane | T14 lane | Exit gate |
| --- | --- | --- | --- |
| One bounded playback/capture procedure and owner listening check; inspect topology, UCM and APM messages where a route fails. | Speaker is heard; verify channels, headset, mic signal and mute/volume. | Physically confirm speakers, channels, headset and microphones; PipeWire sources alone are not a pass. | Audible playback and usable microphone signal on each machine, or a specific failed route with logs. |
| Check ordinary controls and pointer devices; keep board EC work separate. | Confirm ordinary keyboard/pointer use and manual brightness control. HP Fn/media keys and keyboard lighting remain deferred pending platform event/protocol work. | Inspect rejected extra-button mappings and `platform::kbd_backlight`; confirm physical light and TrackPoint cable state before attributing failure to software. | Ordinary controls work without regression; record T14 controls separately. HP Fn is not a Phase 1 exit gate. |
| Shared pairing/reconnect test with separate board transport diagnosis. | `hci0` exists; pair and reconnect a real device, then assess optional firmware warnings. | BlueZ is enabled but its condition is unmet and no HCI appears; compare transport, DT and firmware with the 7.0 baseline. | A controller pairs and reconnects on each board, or the blocker is localized. |

Use the earliest coherent hardware package or live-image change as the next
physical ISO handoff; avoid combining unrelated audio, EC and Bluetooth fixes
merely to reduce the number of images.

### Staged actual-reboot kernel capture

Owner requested actual shutdown evidence before further isolation trials.
On the T14 boot `ccce0afb-58d8-4fd3-bd4e-79d423bc6734`, staged a runtime-only
`t14-reboot-capture.service` with `DefaultDependencies=no`, no shutdown conflict,
and a 30-minute lifetime. Reads `/dev/kmsg` and writes each record synchronously
to `/var/tmp/t14-reboot-capture-20260921/kernel.log`; verification marker confirmed
on disk. On the first new ath12k failure, requests blocked-task stacks immediately
and once more 15 seconds later. These diagnostic writes can affect timing.
Source and unit are retained under
`build/hp-thinkpad/wifi-diagnostics/t14-reboot-capture/`.

Console loglevel temporarily raised from 0 to 7; `plymouth-reboot.service`
runtime-masked to expose shutdown text. All runtime configuration disappears
on reboot; evidence remains on disk. No UKI, DTB, network or Bluetooth changes.
Recorder still dies during final userspace termination and cannot guarantee
capture of late driver teardown. Owner should video the shutdown console to
cover that gap, reboot normally, and unlock the usual boot entry. Reboot has
not yet been initiated; capture expires 30 minutes after staging if unused.
Retrieve this file and previous-boot journal after return before drawing a
conclusion. HP untouched.

### Actual reboot result — journal retrieved

T14 returned on boot `5ae0ec97-3c68-4935-a696-44ff0bc05ea0`.
The owner reported that the phone video did not record. The additional recorder
had reached its 30-minute service limit at monotonic 2431.135 seconds;
shutdown began around 3955.45 seconds (about 25 minutes after capture expired).
Consequently its saved kernel.log does NOT cover shutdown, and no diagnostic
blocked-task dumps were triggered for it. No pstore evidence was available.
The previous-boot journal was retrieved to
`build/hp-thinkpad/wifi-diagnostics/t14-reboot-capture/previous-boot.log`.

Observed monotonic sequence:

- 3955.537: Bluetooth service stopped.
- 3956.058: `pcieport 0004:00:00.0: pciehp: Slot(0): Link Down`.
- 3956.835: NetworkManager and wpa_supplicant begin stopping.
- 3957.091: ath12k firmware-stat timeout; subsequent WMI stats, management-frame
  and key-removal commands time out, with failures returning -11.
- 3961.885: NM/wpa first stop timeout and SIGKILL; another timeout at 3972.385.
- 3977.634: services reported stopped, after approximately 20.8 seconds;
  journal also says processes remain (see full evidence).

The PCIe link drops approximately 0.52 seconds after BlueZ exits and 0.78 seconds
BEFORE NM shutdown starts. This strengthens the shared-power/shutdown-ordering
hypothesis; it does not prove which action caused the link loss. Final kernel
shutdown delay remains uncaptured. Do not claim a full reboot duration from the
wall clock. Next isolated experiment remains Bluetooth power-off with local
capture and independently armed recovery; no further experiment was run here.
Runtime recorder and Plymouth mask are gone after reboot, console loglevel is
back to 0, HP untouched. For a future reboot capture, start its bounded recording
window when the owner is ready to reboot rather than allowing it to expire while
waiting.

### Bluetooth power-off isolation — access lost, evidence pending

Owner switched Bluetooth off after the signal. Before that, Bluetooth was
powered and wlan0 connected on boot `5ae0ec97-3c68-4935-a696-44ff0bc05ea0`.
Local synchronous kernel capture was armed for four minutes in
`/var/tmp/t14-bt-poweroff-20260921/kernel.log`; source retained under
`build/hp-thinkpad/wifi-diagnostics/t14-bt-poweroff/`.
Independent recovery timer scheduled Bluetooth power-on at 19:57:18 EDT,
followed by Wi-Fi reconnection if needed, with a 70-second service cap.
SSH timed out after the owner's confirmation and subsequently returned
No route to host. Access did not return during the recovery window.
This reproduces loss of remote access without rebooting, but the PCIe/kernel
failure and recovery actions are not yet verified: logs remain on the laptop.
No driver reload, boot changes, HP changes, or further trial performed.
Retrieve kernel.log and recovery.log after owner restores access. Do not
repeat the experiment or overwrite those paths before collecting evidence.

### Post-test reboot: Wi-Fi absent — IMG_0400

Owner reports nmcli exposes only lo; rfkill exposes only unblocked Bluetooth.
Photo `/home/bobp/Downloads/IMG_0400.JPG` shows ath12k detecting WCN7850 hw2.0,
MHI power-on setup and a firmware version, then at 17.48s PCIe AER:
`can't recover (no error_detected callback)`. Scan-abort and WMI vdev-delete
timeouts follow. WCN 1P9/0P95 regulator disabling appears at 32.23s, followed
by `qmi failed to send wlan mode off` at 33.76s. At 222.00s MHI fails to clear
reset and ath12k reports `link down error during global reset`.
This is driver/device failure after initial detection, not merely a missing
bar control. Regulator-disable lines occur AFTER initial PCIe failure and
cannot alone establish its cause. The photographed lspci filter used domain
`004` rather than `0004`, so its empty output is not evidence of device absence.
Full local test logs still await access recovery. Recommend saving this boot's
kernel journal and one normal power-off/start with Bluetooth left enabled;
no guarantee that this fully resets shared hardware power state.

### Retrieved isolation evidence and live HP comparison

After owner-reported power-off/start restored T14 Wi-Fi, retrieved kernel.log,
recovery.log, failed-boot.log and test-boot-journal.log into
`build/hp-thinkpad/wifi-diagnostics/t14-bt-poweroff/`. Both machines currently
report wlan0 connected and kernel 7.2.6-1. These checks were read-only.

Test journal records `rfkill: block set for type bluetooth` at 185.571s;
PCIe Link Down follows at 189.057s. Kernel stacks at 194.156s show the PCIe
hotplug IRQ thread in ath12k WMI/flush work on the device-removal path and
NetworkManager in an uninterruptible kernel wait. Wi-Fi teardown proceeds
through ath12k_pci_remove/pciehp_unconfigure_device with WMI timeouts; QMI
WLAN-mode-off fails at 237.538s. Thus the isolated Bluetooth-block operation
reproduces the link-loss and teardown failures without a reboot.

Recovery-script limitation: the bar used rfkill block, whereas the script only
called `bluetoothctl power on`. BlueZ rejected that with Error.Failed and reported
`PowerState: off-blocked`; wlan0 was already missing and nmcli could not reconnect.
This was NOT a valid test of recovery after rfkill unblock. Any later recovery
procedure must account for the block explicitly; do not rerun merely to fix the
harness now. Owner subsequently turned Bluetooth on, but reports warm reboot
left Wi-Fi absent; full power-off/start restored it.

Live dependency snapshots `power-53.txt` and `power-42.txt` confirm:
T14 wcn7850-pmu has a Bluetooth serial consumer only, with no PCI Wi-Fi of_node.
HP wcn6855-pmu has both serial Bluetooth and a platform Wi-Fi power consumer,
and PCI Wi-Fi maps to the DT wifi@0 child. Owner separately reports independent
Bluetooth/Wi-Fi toggling works on HP. This makes T14's missing Wi-Fi shared-power
consumer the leading correction to pursue, still requiring a controlled bootable
trial. Do not reuse the failed single-.dtb UKI: preserve the shipped .dtbauto boot
layout and known-good fallback when a new candidate is authorized. No boot files,
radio states, drivers, or HP configuration changed during evidence retrieval.

## Phase 2 — Suspend, wake and battery behavior

**Quality-of-life reason:** sleep failure or unexpected drain can make a
portable computer unreliable even when its desktop works.

| Shared work | HP lane | T14 lane | Exit gate |
| --- | --- | --- | --- |
| Record matched idle and unplugged baselines, then supervised suspend/wake. Check storage, network and newly working peripherals afterward. Change `clk_ignore_unused` or `pd_ignore_unused` only against measurements. | Check both charging ports, resume of Wi-Fi/audio/USB and battery drain. | Check both ports, resume of keyboard/USB/audio and the reported 75%/80% charge thresholds. | Repeatable wake with essential functions restored, measured sleep drain and understood charge behavior. |

Keep battery capacities and workloads distinct by board. Do not infer runtime
from a short uncontrolled sample or install a polling daemon. If a power fix
touches kernel or DT behavior, build one scoped candidate and stop for testing.

## Phase 3 — Cameras

**Quality-of-life reason:** both machines currently fail RGB camera
enumeration; video calls remain unavailable.

| Shared work | HP lane | T14 lane | Exit gate |
| --- | --- | --- | --- |
| Compare Dragon CAMSS/CCI bindings with the older physically validated paths. Reuse one bounded capture procedure while keeping sensor and board wiring separate. | Port the OV05C10 driver correction and HP graph to the current kernel/DT ABI. | OV02C10 and CAMSS are configured as modules, but the selected DT has no camera graph; port its CCI/CAMSS wiring and check normal-user DMA heap access. | Per board: `cam -l`, two ten-frame direct captures, ten PipeWire frames, owner-confirmed preview, repeat after reboot. |

Libcamera is already installed. It cannot create a missing DT graph. Keep the
HP and T14 sensor changes separate for review and do not mix Ubuntu modules
with the Arch kernel.

## Phase 4 — Shared cDSP transport, then NPU

**Quality-of-life reason:** the NPU is valuable once basic laptop use is
reliable. Both machines fail the same cDSP QRTR/FastRPC endpoint step, making
this one shared investigation before board-specific inference checks.

| Shared work | HP lane | T14 lane | Exit gate |
| --- | --- | --- | --- |
| Compare Dragon's DT, GLINK/RPMsg and FastRPC channel setup to the 7.0 baseline. Trace the `-12` endpoint failure before running QNN; the code alone does not establish memory exhaustion. | Restore `/dev/fastrpc-cdsp` with matched HP firmware while retaining working ADSP/audio. | Restore the endpoint with the validated Lenovo firmware and matching shells/libraries. | On each: cDSP device opens; calculator returns `499500`/`999`; validator passes; explicit HTP backend ID 6 ReLU yields `[0,0,0,3]`. Cleanup and reboot repeat. |

Keep proprietary SDK binaries and private logs out of the public repository
and ISO. Run the local harness on demand without a permanent NPU service.

## Phase 5 — Polish and reviewable Dragon contributions

Test actual GPU rendering, USB ports and external displays on both machines.
Investigate the HP BOE panel warning if visual behavior is wrong. Treat TPM
availability and Secure Boot as separate questions. Recheck already working
features after kernel or power changes.

Split contributions into board-aware live USB policy, reusable hardware
recipes, the shared transport fix, separate camera integrations and concise
validation evidence. The prior PR's long hardware narrative belongs in a
discussion or workbook; source PRs should describe concrete changes and tests.
Fetch the latest Dragon before rebasing each focused branch. Coordinate with
the team's package owners before overlapping their methods. Do not publish
vendor firmware or SDK payloads without a distribution decision.

## Handoff rule for every phase

At the earliest step that answers a physical question, build **one proposed
ISO for both machines**, check its contents and boot metadata, copy it to
`~/ISOs`, give the owner its path and **stop**. The owner writes and tests it,
then offers SSH for the next comparison. Do not wait for every gap in a phase
to close before this handoff. USB writing and machine reboots are separate
owner-directed actions.

## Public source checkpoint

Owner requested committing/pushing the work before continuing T14 remediation.
Fetched Dragon: base remains `f97a775823c53069c003a4c620692cdb11fe7de0`.
Destination is fork `bprendie/omarchy-iso`, branch `experiment/hp-thinkpad-dragon`.
The source checkpoint includes experimental build changes, package recipes,
board overlays, investigations, gap analyses and this workbook. No ISO build,
firmware upload, radio change or additional physical test accompanies it.

Owner correctly identified that omitting private firmware leaves a rebuild gap.
Added `experiments/hp-thinkpad/inputs/README.md` and package/final-payload manifests
with original acquisition and extraction details. Binary redistribution terms
for the retained HP/Lenovo inputs remain unresolved. The README explicitly marks
this as an experimental source checkpoint, not a clean-checkout reproducible
release. A pinned fetch/extract workflow and clean ISO assembly remain required.

Validation: 18 shell syntax checks, Python parse, platform JSON parse and BusyBox
boot-diagnostic behavioral test pass. Selected existing suite: 42/45 passed;
three Aarch64CustomizeTest cases fail on missing `/etc/pacman.conf` in the fixture.
The new Snapdragon prerequisites also require fixture inventory updates. These
failures are preserved/documented rather than obscured in a checkpoint commit.

## Clean Snapdragon source build

Replaced retained package inputs with direct, pinned vendor acquisition and
byte-for-byte output verification. `fetch-firmware.py` verifies HP SP162865,
Lenovo N42QQ23W, the Ubuntu firmware source ISO and AudioReach sources, extracts
only the board payloads, builds the topology and checks the final file manifests.
`prepare-packages.py` now consumes that verified directory, generates the HP DMIC2
profile and includes provenance/licenses. All references to the earlier project's
name and external repository paths were removed from the tracked tree.

Added `bin/omarchy-iso-make-snapdragon` to fetch pinned official Dragon runtime and
package recipes and invoke the existing `--local-source` builder contract. The
edge channel lacks the two ARM helper packages; fetch their exact upstream PR
recipes instead. Retain a small explicit recipe patch for ARM UEFI Limine files
and dependencies until the package channel supplies those contracts. These
adaptations live inside the disposable build, not on either physical machine.

The regular Snapdragon build now creates its hardware repository from source,
keeps the selected published Omarchy repository, stages the tested T14 tree before
normal `.dtbauto` UKI creation, and includes the tested HP/T14 early-DSP menu entry.
The standard menu entry retains its DSP guard for other boards. Generic ARM
only adds the early hardware hook if that package is present. Sandbox disabling
is now conditional on the emulation opt-in even in the offline build config.

Removed the dated staged-root/previous-ISO repacking helpers and replaced their
active instructions with the clean-build command. Historical findings remain
identified as history. T14 shared-power remediation remains deferred; the known
Bluetooth-off/Wi-Fi regression is explicitly documented in the build README.

Validation so far: a fresh native container downloaded all four public inputs,
rebuilt topology, and verified all selected firmware hashes. A fresh ARM container
built all four board packages and reproduced both T14 DTB hashes. The selected
52-test Python suite, shell/Python/JSON syntax checks, BusyBox boot-diagnostic test,
and both upstream ARM-helper test scripts passed. Source checkout/patch application
was tested from public Git remotes. Final combined ARM package contract validation
is recorded below when complete. No full ISO assembly or physical test is part of
this build-script change; full ISO acceptance remains a separate next step.

Final package validation passed: all six board/support packages built in the
isolated ARM container, followed by the pinned Dragon runtime/settings packages.
`builder/check-arm-packages.sh aarch64/snapdragon` passed against those actual
archives. The first settings-only test environment omitted ImageMagick (which
`builder/build-iso.sh` already installs); rerunning with that builder dependency
passed. Arch Linux ARM also successfully supplied libpisp directly, so its old
retained-package workaround is unnecessary. Logs and generated artifacts remain
under ignored `build/clean-hardware/`; none are public source dependencies.
The updated 52-test suite is green, including the former three fixture failures.
Full ISO assembly, Neovim's source-package build and physical boot of this new
assembly have not been rerun in this task; do not equate package validation with
hardware acceptance.
