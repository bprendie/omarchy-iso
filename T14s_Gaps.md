# ThinkPad T14s Gen 6: hardware and capability gaps

SSH inventory of `bobp@10.0.0.53` (`bp-t14s`) on **2026-09-21**, approximately
16:04–16:08 EDT. This report follows the structure of
[HP_Elitebook_Gaps.md](HP_Elitebook_Gaps.md). Passwordless sudo was used for
read-only kernel, boot and device-tree inspection. Camera enumeration was
queried as both the user and root. No package/configuration changes, playback,
recording, camera capture, DSP restart, reboot or suspend were performed.
An unresponsive diagnostic `bluetoothctl show` process was terminated;
no Bluetooth service or hardware state was changed.

Detected hardware, driver availability and firmware startup are not functional
passes. Earlier oma_snap results are baselines, not results for this installation.

## System under test

| Item | Observed |
| --- | --- |
| Machine | Lenovo ThinkPad T14s Gen 6, product `21N10000US` |
| Firmware | `N42ET92W (2.22 )`, dated 2025-06-27 |
| Device tree | `Lenovo ThinkPad T14s Gen 6 (LCD)` |
| CPU / memory | 12 online Qualcomm Oryon cores; 30 GiB usable RAM; 30 GiB swap |
| OS / kernel | `omarchy-dev 4.0.0.r2186.gee8ebf6-1`; `linux-aarch64 7.2.6-1`; running `7.2.6-1-aarch64-ARCH` |
| Hardware packages | `omarchy-hw-t14s-experimental 0.2-1`; `omarchy-hw-snapdragon-early-experimental 0.3-1`; `linux-aarch64-pkgbase-shim 1-3` |
| Boot | UEFI → Limine 12.9.0 → ARM64 UKI through systemd-stub 261.3; Secure Boot disabled |
| Storage | WD PC SN740 `SDDQMQD-1T00-1201`, 953.9 GiB; 2 GiB FAT ESP, LUKS-encrypted Btrfs root |
| Installed root | `/dev/mapper/root[/@]`; `/home`, package cache and logs mounted from the installed Btrfs filesystem |

No system services are in the failed state. Bluetooth is inactive with an
unmet start condition, which is not represented as a failed service. The
installed runtime package is newer than the ISO's original `r1.g66a33c3`
runtime, which remains identified in its initial snapshot entry.

## Capability matrix

`Works` means the observed operation succeeded. `Detected` means interfaces
exist but the user-facing function is unverified. `Fails` describes an observed
missing interface or failed check. `Untested` requires additional validation.

| Area | Current evidence | State / gap |
| --- | --- | --- |
| Live installer and installed boot | Owner reached the installer and completed installation using the DSP-enabled A/B image. SSH now runs from encrypted internal storage. NVMe and both partitions are present; no USB installation drive appears in the current inventory. | **Works** for this installation and installed boot. Repeated cold boot, visible unlock, kernel update and rollback still need validation. |
| CPU, RAM and thermals | 12 cores online, 30 GiB RAM and swap; CPU/cluster temperature readings roughly 41–45 °C in this snapshot. | **Detected**. No load, throttling, performance or battery-efficiency test. |
| Wi-Fi | WCN785x / FastConnect 7800 bound to `ath12k_wifi7_pci`; SSH works over `wlan0`. Link reports 5240 MHz, 160 MHz EHT and approximately −43 dBm. | **Works** for this connection. Negotiated rates are not measured throughput; roaming, reconnect and resume remain untested. |
| Bluetooth | BlueZ 5.87-2 installed; service enabled but inactive, `ConditionResult=no`; `/sys/class/bluetooth` absent, no HCI controller or Bluetooth rfkill entry. The scanned running DT has no Bluetooth node. | **Fails controller enumeration on this boot**. Determine the intended board transport and missing binding/initialization; merely enabling the service is not the missing step. |
| Internal display / brightness | eDP connected and enabled at 1920×1200. Kernel recognizes BOE NE140WUM-N6G (`0x0b66`). Backlight reads 3276/4095. | **Works for visible installer use**, with the installed display interface active. Brightness keys, range, refresh behavior and visual quality untested. Unlike the HP, this panel is identified without the reported unknown-panel warning. |
| GPU | DRM card and render node exist; kernel reports loaded GMU firmware v4.3.17; Mesa/freedreno 26.2.3 installed. | **Detected**. No Vulkan upload, rendering or OpenGL test was run on this T14. Do not transfer the HP's Vulkan result. |
| Keyboard / touchpad / TrackPoint | I²C keyboard and touchpad registered, plus `ThinkPad Extra Buttons`. Several `EVIOCSKEYCODE` mappings fail with `Invalid argument` on the extra-button device. | **Detected**; ordinary keys, gestures and Fn actions need physical checks. Earlier oma_snap notes say the TrackPoint cable was disconnected pending keyboard replacement; current hardware condition is not confirmed. |
| Keyboard backlight / EC | `lenovo_thinkpad_t14s` loaded, bound to `thinkpad-t14s-ec`; `platform::kbd_backlight` reads 0 with maximum 2. Mute, mic-mute, power, lid-logo and charge LEDs are exposed. | **Detected**. No brightness write was attempted. Earlier 7.0 testing accepted a write but read back zero; that historical failure does not establish current Dragon behavior. |
| Speakers / headset | ALSA exposes two playback PCMs. PipeWire has a default speaker sink at 0.40 and an HDMI playback sink. Boot log contains an APM command timeout. | **Detected**, not an audio pass or proven failure. No sound was played or physically confirmed in this scan. Test speakers, channel separation, volume and headset routing. |
| Microphones | Two ALSA capture PCMs and PipeWire internal/headset microphone sources exist. | **Detected**. Stream opening, signal level, routing and usable audio remain untested; no recording was made. |
| RGB camera | No `/dev/video*` or `/dev/media*`. Both user and root `cam -l` list no cameras. Running DT scan finds camera reserved memory and thermal entries, but no sensor/CCI/CAMSS device graph. Kernel enables `CONFIG_VIDEO_QCOM_CAMSS=m` and `CONFIG_VIDEO_OV02C10=m`. | **Fails enumeration**. Board camera graph/integration is missing despite driver availability. User-level enumeration also reports no usable DMA-buffer provider; DMA heaps exist but are root-only. Root enumeration still fails, so permissions alone cannot explain the missing camera. |
| cDSP / FastRPC / NPU | ADSP and cDSP remoteprocs are `running`. cDSP QRTR and FastRPC both fail endpoint creation with `-12`. `/dev/fastrpc-adsp` exists; neither expected cDSP node exists. | **Fails cDSP transport preflight**. No calculator, validator or QNN inference was attempted. Same failure pattern as the HP; running cDSP firmware is not an NPU pass. |
| Battery / charging | USB power online; battery reports charging at about 10.1 W and 96.9%, 29 cycles, 59.18 Wh learned full capacity versus 58 Wh design. Two UCSI power-source interfaces exist; the second reports online. | **Detected and reporting charge input**. Sustained charging, both ports and unplugged runtime are untested. Reported 75%/80% charge thresholds coexist with charging above 96%; validate actual threshold behavior before claiming enforcement. |
| Suspend / hibernate | Kernel exposes `freeze mem disk`; `s2idle [deep]`; resume parameters and swap exist. | **Untested**. Availability of a power state does not prove suspend, wake, hibernate or low drain. |
| USB / external displays | Live USB rootfs copy and installation succeeded with early DSP enabled. Installed system exposes USB2 and USB3 root hubs, plus internal device `06cb:00f9`. External DP/HDMI connectors are disconnected. | **Works for the owner's installer USB path**. Do not generalize to every port. Per-port data transfer, docks, hotplug, alt mode and wake remain untested. USB root-hub speeds are capabilities, not measured transfers. |
| Fingerprint | Internal USB device `06cb:00f9` enumerates. | **Detected device only**. No enrollment, authentication or userspace compatibility check. |
| TPM / Secure Boot | No `/dev/tpm*`; bootctl reports TPM2 firmware support with driver unavailable. Secure Boot disabled. | **Gap for Linux TPM use on this boot**. Secure Boot is disabled configuration, not a failed enablement test. No security or firmware settings changed. |

## Boot regression: evidence and remaining integration

The bootdiag image reached an initramfs rescue shell because its installation
USB was absent as a block device; its NVMe was already detected. The subsequent
A/B image retained the exact kernel, DTs, initramfs and root filesystem, and
removed only `modprobe.blacklist=qcom_q6v5_pas` from the default entry's kernel
arguments. It also displayed a menu with the previous behavior as a fallback.
The owner then reported rootfs copying, installer startup and completed installation.

This is strong physical evidence that the early DSP policy affected T14 live
USB access. It does not prove the precise USB power/mux mechanism or justify
removing the blacklist for every Snapdragon board. Installed boot has no DSP
blacklist, and both DSPs run. PMIC GLINK device-link warnings persist on this
working T14 and on the HP; those warnings alone are not failure diagnoses.

The production integration gap is a board-aware live DSP policy through
Dragon's existing boot methods, retaining the protection required by other
machines. See [the USB investigation](experiments/hp-thinkpad/t14-usb-investigation.md)
and [the test menu](experiments/hp-thinkpad/grub-t14-dsp-test.cfg). The main
experimental GRUB config still contains the blacklist; the successful A/B
menu has not yet been promoted to a general upstream fix.

## Gap analysis and work order

| Priority | Gap / layer | Next decisive step | Completion criterion |
| --- | --- | --- | --- |
| 1 | Shared HP/T14 cDSP transport | Compare matched firmware, DT channel definitions and GLINK/RPMsg handshake against the working 7.0 baseline. Both boards fail cDSP QRTR and FastRPC endpoint creation. The `-12` message alone does not prove memory exhaustion. | cDSP device opens, calculator returns `499500`/`999`, validator passes, explicit HTP ReLU returns `[0,0,0,3]`; cleanup and reboot repeat succeed. |
| 1 | T14 camera graph | Port the working OV02C10/CCI/CAMSS board wiring to Dragon's matched kernel bindings; check sensor supplies, clocks and endpoints. Then resolve DMA-heap access for normal-user libcamera operation. | Sensor and media graph enumerate; two ten-frame direct captures and a ten-frame PipeWire capture pass; owner confirms preview; repeat after reboot. |
| 1 | Bluetooth board integration | Identify the board transport and compare its DT/driver path with the working baseline. Service enablement already exists; HCI does not. | Controller enumerates, service starts, device pairs and reconnects; audio/data and resume checked as applicable. |
| 1 | Promote successful live USB policy | Convert the T14-only A/B result into board-scoped behavior through Dragon's existing workflow; retain other boards' known USB protection. | Fresh image installs and reboots on both T14 and HP; live USB remains available through rootfs copy. |
| 2 | Audio and microphone validation | Test playback with owner confirmation and bounded capture with signal validation; correlate any failure with the APM timeout. Reuse the HP procedure, not its result. | Audible correct channels, usable microphone signal, volume/mute and headset routes verified. |
| 2 | Fn keys / EC / keyboard lighting | Confirm current keyboard and TrackPoint hardware state; inspect rejected extra-button keymaps and test the exposed EC controls. | Labeled keys and lighting physically work; no regression to ordinary keys or pointer input. |
| 2 | Suspend, charge thresholds and battery | Measure baseline power, then controlled suspend/wake with user present. Evaluate the existing `clk_ignore_unused`/`pd_ignore_unused` workarounds only against measured behavior. Validate thresholds against charging observations. | Resume restores storage, network, audio and validated peripherals; measured sleep drain and charge behavior acceptable to the owner. |
| 3 | GPU / external devices / security | Run an actual GPU workload, each USB port and external display path; separately determine exposed TPM support and signed boot requirements. | Verified outputs/transfers; TPM usable where supported; intended boot trust chain separately tested. |

The shared NPU transport investigation should be done once across both boards.
Camera framework work can also be shared, but HP OV05C10 and T14 OV02C10 sensor
and board wiring remain distinct. The T14 already has its sensor driver built
as a module; this is not the HP's missing-sensor-driver situation.

## Comparison with the earlier successful T14

The [oma_snap T14 follow-up](../oma_snap/docs/t14s-camera-backlight-npu.md)
records physical tests on kernel `7.0.0-31-generic`: OV02C10 direct capture,
owner-confirmed preview and PipeWire capture succeeded after userspace packages
were added. Those userspace packages are now present on Dragon, but the board
camera graph is not. Reinstalling libcamera alone will not restore that graph.

Earlier NPU validation required Lenovo's matched cDSP firmware and runtime.
The current cDSP image is 3,195,304 bytes, and both cDSP firmware files hash
identically to the HP/T14 experiment's staged Lenovo payload. Endpoint creation
still fails before a QNN test can run. Do not replace firmware arbitrarily or
reuse Ubuntu kernel modules in the Arch kernel.

The earlier keyboard-backlight problem was unresolved, and its disconnected
TrackPoint condition needs reconfirmation. Neither is a known solved feature
that can simply be copied from 0.1.2.

## Firmware and diagnostic anchors

Files below are in `/usr/lib/firmware/updates/qcom/x1e80100/LENOVO/21N1/`:

| File | SHA-256 |
| --- | --- |
| `qcadsp8380.mbn` | `fc2da4b4b7607ad472594aee4af6e4f96de46e36c4b40c2e426c244007421c97` |
| `qccdsp8380.mbn` | `4a67a03367f2eff2f8a0e867ca25d2bf2fcd5aee3e41e2c9f436c804e257c789` |
| `cdsp_dtbs.elf` | `93941f040da14b8305d39579686d886706d22954a538b03da676c1aaa191797f` |
| `X1E80100-LENOVO-Thinkpad-T14s-tplg.bin` | `aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5` |

Evidence sources: hostname/DMI, running DT sysfs, `uname`, `lscpu`, `free`,
`lsblk`, NVMe model sysfs, `findmnt`, `bootctl`, Limine configuration,
`/proc/cmdline`, `/proc/config.gz`, package queries, PCI/USB/DRM/input/LED sysfs,
NetworkManager and `iw`, Bluetooth unit state, ALSA enumeration, `wpctl`,
user/root `cam -l`, DMA-heap permissions, remoteproc state, firmware hashes,
UPower, kernel and system journals. No new hardware functionality is claimed
from package presence alone.
