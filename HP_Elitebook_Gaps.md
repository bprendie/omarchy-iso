# HP EliteBook Ultra G1q: hardware and capability gaps

SSH inventory of `bobp@10.0.0.42` (`bp-elite`) on **2026-09-21**, starting about 14:51 EDT. This describes the installed **HP**, not the separate ThinkPad T14s boot attempt. A detected device or loaded firmware is not an end-to-end hardware pass. After the initial inventory, passwordless sudo was used for read-only boot/kernel inspection; short speaker, microphone-open and Vulkan upload tests were also run. No reboot, suspend, package change or persistent configuration change was made.

## System under test

| Item | Observed |
| --- | --- |
| Machine | HP EliteBook Ultra G1q 14 inch Notebook AI PC; board `8CBE`, revision `17.45`; UEFI `F.34` dated 2026-06-26 |
| SoC / memory | Qualcomm X1E80100, 12 online Oryon cores, 30 GiB usable RAM |
| Device tree | `HP EliteBook Ultra G1q`; compatibles `hp,elitebook-ultra-g1q`, `qcom,x1e80100` |
| OS / kernel | Omarchy `4.0.0.r2186.gee8ebf6`, `linux-aarch64 7.2.6-1` |
| Local hardware packages | `omarchy-hw-hp-experimental 0.2-1`, `omarchy-hw-snapdragon-early-experimental 0.2-1`; `linux-aarch64-pkgbase-shim 1-3` |
| Boot | UEFI → Limine 12.9.0 → installed ARM64 UKI; LUKS root on Btrfs; Secure Boot disabled; `/boot/limine.conf` contains the current UKI and one snapshot entry |
| Internal storage | Kingston SNV2S2000G / NV2, 1.8 TiB NVMe; 2 GiB FAT `/boot`, encrypted Btrfs root; mounted and working |

The current boot's `systemctl --failed` list is empty. The installed runtime is newer than the `r2015` baseline in [the earlier HP evidence](experiments/hp-thinkpad/phase-0-1-evidence.md). The same kernel version and major HP hardware gaps remain. The T14s storage and PCIe investigation has its own [boot note](experiments/hp-thinkpad/t14-power-boot.md); this HP's working NVMe does not settle that board's boot problem.

## Capability matrix

`Works` means the observed function operated during this scan. `Detected` means the kernel or userspace exposes it, with the user-facing function still untested. `Fails` means the expected interface is absent or a prior physical failure is documented. `Untested` requires a physical or active check.

| Area | Current evidence | State / gap |
| --- | --- | --- |
| Installed boot and storage | Running from encrypted Btrfs on `/dev/nvme0n1`; NVMe driver bound, root mounted, SSH reachable. | **Works** for this boot. Reboot, unlock display, update and rollback untested. |
| CPU and memory | 12 cores online; 30 GiB RAM and 30 GiB swap available. | **Detected**; no load, performance or hibernate test. |
| Wi-Fi | WCN785x / FastConnect 7800 PCIe card bound to `ath12k_wifi7_pci`; `wlan0` connected at 5 GHz, 160 MHz; SSH works over it. | **Works** for current network connection. Wi-Fi 7, roaming and reconnect untested. |
| Bluetooth | `hci0` is powered and unblocked. Boot log reports missing `qca/wcnhpbtfw20.tlv` and `qca/hpbtfw20.tlv`, while the controller still initializes. | **Detected** now; earlier owner report says Bluetooth works. Pairing, audio and reconnect not retested. Determine whether the missing optional firmware affects features. |
| Internal display and brightness | `msm_dpu` bound; eDP connected and enabled at 2240×1400; backlight interface is present at 86/100. | **Detected** and boot display apparently operational; brightness keys, dimming range and visual quality untested. Kernel warns about unknown BOE `0x0d3b` panel and uses conservative timings. |
| GPU acceleration | `/dev/dri/card0` and `renderD128` exist. The kernel loads `gen70500_sqe.fw` and `gen70500_gmu.bin` from the new location after initial lookup failures. FFmpeg selected the integrated Adreno X1-85 Vulkan device and uploaded three frames to Vulkan surfaces successfully. | **Works for Vulkan device creation and frame upload**. Graphics rendering, display performance and OpenGL remain untested; the early firmware errors are not a persistent firmware gap. |
| Keyboard / touchpad | HID-over-I²C keyboard and touchpad have input events. Only ordinary lock-key LEDs appear in `/sys/class/leds`. | **Detected**; typing, gestures, Fn keys and keyboard backlight untested. No keyboard-backlight control was found in the scanned LED class. |
| Speaker / headset audio | ALSA card 0 has two playback PCMs; PipeWire exposes a speaker sink. A bounded 48 kHz stereo `speaker-test` opened the default route and played its 440 Hz tones; the owner confirmed hearing audio. The command was stopped by its six-second timeout. | **Speaker playback works on this boot**, superseding the earlier no-audio report. Channel separation, quality, volume range and headset playback remain untested. The boot-time APM timeout and no-backend warning still merit investigation if symptoms recur. |
| Microphones | ALSA has two capture PCMs; PipeWire exposes internal and headset microphone sources. A two-second, 48 kHz stereo `arecord -D default` stream completed into `/dev/null` with exit code 0. | **Capture stream opens**; microphone signal, routing, level and headset mic remain unverified because no sample was retained or listened to. |
| RGB camera | `cam -l` returns no cameras; `/dev/video*` and `/dev/media*` do not exist. The selected HP DT has no active camera/CCI/CAMSS graph in the scanned tree. Kernel config has `CONFIG_VIDEO_QCOM_CAMSS=m`. | **Fails enumeration**. Earlier build notes say the HP OV05C10 driver and board camera graph were not shipped. Sensor driver, DT wiring and capture validation remain needed. |
| cDSP / FastRPC / NPU | HP cDSP remoteproc is `running`, but `/dev/fastrpc-cdsp` is absent. `qcom,fastrpc` and cDSP QRTR endpoint probes fail with `-12`. A root-level `O_RDWR` open of `/dev/fastrpc-cdsp` and `/dev/fastrpc-cdsp-secure` returned `ENOENT`; opening `/dev/fastrpc-adsp` succeeded. | **Fails cDSP transport preflight on this Dragon boot**. The QNN HTP graph cannot run through the expected cDSP endpoint. The exact cause of endpoint creation failure is not established; this is not evidence of a defective NPU chip. |
| Battery / charging | UPower sees a 56.96 Wh full battery versus 59.16 Wh design (~96.3% health), 25 cycles, 100% charge, USB power online. Two USB-C UCSI ports are registered; port 0 has a partner. | **Detected**; current power input is visible. Charge-rate behavior, unplugged runtime, both ports, USB data and DisplayPort alt mode untested. |
| Suspend / hibernate | Kernel exposes `freeze`, `mem` and `disk`; `deep` is selected in `/sys/power/mem_sleep`. Boot has a resume parameter and 30 GiB swap. | **Untested**. This does not establish suspend, wake, hibernate or battery drain. |
| TPM / Secure Boot | `bootctl` reports TPM2 firmware support but driver unavailable; no `/dev/tpm*`; Secure Boot disabled. | **Gap** for TPM-backed Linux use on this boot. No enrollment or security change attempted. |
| External devices | Two DRM DisplayPort connectors are disconnected. No USB device was enumerated in sysfs; `lsusb` is not installed. | **Untested** for docks, external displays, USB peripherals and both USB-C ports. |

## Gap analysis and work order

The HP has a working installed storage/boot path, Wi-Fi connection and physically confirmed speaker playback. Its GPU passes device creation and upload, while microphone capture only passes stream opening. Two failures are directly established: camera enumeration and cDSP messaging. The remaining rows mostly describe incomplete validation or platform features that were already unresolved on the older build.

| Priority | Gap and likely layer | Confidence and next decisive step | Completion criterion |
| --- | --- | --- | --- |
| 1 | **NPU: cDSP GLINK/RPMsg connection** | Confirmed endpoint failure, unknown cause. Compare exact Ubuntu/Arch cDSP DT and transport implementations; trace the failing channel handshake before changing memory reservations or firmware. QRTR and FastRPC both failing on cDSP makes their common transport the first place to investigate. | cDSP endpoint opens; reuse the retained calculator (`499500`, `999`), validator and explicit HTP ReLU (`[0,0,0,3]`) tests; verify cleanup and repeat after reboot. |
| 1 | **Camera: board DT and sensor-driver integration** | High confidence in the missing integration. Reuse the validated OV05C10 driver correction and HP wiring from earlier prototype, adapting to the Arch CAMSS bindings. The earlier stock Ubuntu kernel also lacked the driver and enabled camera graph; its successful camera required custom support. | Camera enumerates; two ten-frame direct captures and a ten-frame PipeWire capture succeed; owner confirms preview; repeat after reboot. |
| 2 | **Suspend, charging and battery use: validation plus power integration** | No suspend or battery-life failure established. Current command line includes `clk_ignore_unused` and `pd_ignore_unused`; the boot log confirms unused clock/domain shutdown is bypassed. This makes power-state testing particularly relevant, but does not quantify drain. Measure a baseline before evaluating either workaround. | Controlled suspend/wake and unplugged discharge measurement; storage, Wi-Fi, audio and any working camera/NPU recover afterward. Test both charging ports. |
| 2 | **Fn/media keys and keyboard backlight: HP platform event/control support** | Historical failure on earlier prototype; current Dragon key behavior untested. Earlier ACPI analysis found an additional EC/WMI event path absent from that DT boot, but did not establish a complete working driver or lighting protocol. Start with current physical key behavior and existing evidence. | Brightness, volume and mute keys perform their labeled actions; keyboard lighting changes physically; normal F-key behavior retained. |
| 2 | **Microphones, headset and USB-C: physical validation** | Interfaces alone are insufficient. Speaker success closes the earlier blanket audio failure. Mic signal, headset routing and USB-C data/display behavior remain open. | Usable microphone signal and headset audio; peripheral transfer and external display output tested on each applicable port. |
| 3 | **Panel warning and GPU coverage** | Panel is enabled and Vulkan upload works. Unknown BOE panel identification deserves investigation, but the warning alone is not a display failure. Check visual timings/brightness and an actual GPU operation before proposing changes. | Correct image, brightness range and a verified rendered/processed output; warning cause understood. |
| 3 | **TPM / Secure Boot** | TPM is unavailable to Linux; Secure Boot is disabled. These are separate findings: disabled Secure Boot is configuration state, not a failed enablement test. Determine the board's exposed TPM interface before choosing a driver change. | TPM device works if supported by the selected platform path; separately validate the intended signed boot chain. |

The two priority-1 items require different fixes: the camera has known board integration to port, while the NPU needs the transport failure localized first. Neither currently justifies replacing the entire kernel or copying Ubuntu modules into Arch. The source of each eventual fix should stay tied to its own hardware evidence.

References for reusable HP work: camera implementation and physical results (historical hardware notes), Fn/EC investigation (historical hardware notes), and NPU acceptance test (historical hardware notes). Camera and NPU success on the earlier build are useful baselines. Fn/backlight were not solved there, and a kernel swap cannot be assumed to solve them.

## Most actionable gaps

1. **Camera bring-up:** The absence of video/media nodes and the camera graph points to missing kernel/DT integration, before libcamera tuning or application testing. The installed `libcamera 0.7.2-4` and `pipewire-libcamera 1:1.6.8-1` cannot compensate for that.
2. **cDSP FastRPC:** The cDSP firmware boots, yet the cDSP QRTR/FastRPC endpoint fails to instantiate with `-12`. Inspect the GLINK channel handshake, endpoint creation and the running DT/kernel before attempting QNN. This is separate from the T14s NVMe boot issue.
3. **Audio endpoints beyond the speaker:** The speaker is now physically confirmed working. Board topology hashes to `aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5`, matching the earlier evidence; the exact DMI UCM alias resolves to `Qualcomm/x1e80100/LENOVO-T14s.conf`. Check headset playback, microphone signal and channel quality. The APM timeout and no-backend warning appeared at boot but did not prevent the tested speaker route.
4. **Panel identification:** The panel works at 2240×1400 but emits a kernel warning at `generic_edp_panel_probe` and an unknown-panel notice for BOE `0x0d3b`. Validate timings and brightness behavior before changing the panel description.
5. **Unverified hardware functions:** Full GPU rendering, USB-C data/alt mode, headset audio, microphone signal, suspend/resume, keyboard backlight and TPM need focused checks. The short Vulkan upload and open capture stream do not establish those broader behaviors.

## NPU retest against the earlier harness

The earlier prototype HP NPU validation (historical hardware notes) ran on the **same physical HP** with Ubuntu kernel `7.0.0-31-generic`: FastRPC calculator returned `499500` and `999`, the Qualcomm DSP validator passed, and the explicit HTP backend ID 6 ReLU graph returned `[0, 0, 0, 3]`. That separate runtime and its final harness are retained in the local earlier prototype evidence/SDK archives, but the earlier result does not transfer to Dragon.

On this Dragon installation, an active privileged device-open preflight stops before the calculator or QNN harness can execute: both cDSP FastRPC device paths return `ENOENT`, while the ADSP FastRPC device opens. The old `~/npu-test` staging directory, `libQnnHtp.so` and `qnn-platform-validator` are also absent from this fresh install. Staging those binaries alone would not restore the missing kernel endpoint. **Current Dragon NPU result: blocked at cDSP FastRPC transport; no HTP inference result.** The previous Ubuntu HTP pass remains valid for that older kernel/runtime combination.

## Firmware and diagnostic anchors

The installed HP firmware files are under `/usr/lib/firmware/updates/qcom/x1e80100/hp/elitebook-ultra-g1q/`. Both remote processors are running with these exact filenames:

| File | SHA-256 |
| --- | --- |
| `qcadsp8380.mbn` | `ada5b3a4c5647b2d3abc4d47205b9e7eaec795c2658a8d63ba406c87acba7f43` |
| `qccdsp8380.mbn` | `4387fa1a234aacbff50f8a215b96536d17c4b25b6b798392e15a162e4adcd7a0` |
| `X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin` | `aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5` |

Other boot warnings include dummy PCIe and GPU regulator supplies, PMIC/USB device-link failures, one early I²C HID empty IRQ, and a Wi-Fi DMA allocation fallback. Storage and Wi-Fi nevertheless initialize. These warnings need correlation with an observed failure before assigning them as causes. The kernel log's initial GPU firmware errors are followed by successful loads.

Evidence came from `hostnamectl`, DMI and live DT sysfs, `lscpu`, `lspci -nnk`, `lsblk`, `bootctl status`, `efibootmgr`, NetworkManager/BlueZ, DRM and input sysfs, ALSA/PipeWire, `cam -l`, remoteproc sysfs, UPower, package queries, firmware hashes, `journalctl -b -k`, privileged `/boot/limine.conf` inspection and `/proc/config.gz`. The installed UKI is present under `/boot/EFI/Linux/`, and Limine has one stored snapshot boot entry. Kernel config has `CONFIG_QCOM_FASTRPC=m`, `CONFIG_VIDEO_QCOM_CAMSS=m`, `CONFIG_SUSPEND=y`, `CONFIG_HIBERNATION=y` and `CONFIG_TCG_TPM=y`; those enabled options do not prove working board hardware. Package presence, nodes, firmware loads, stream opens and physically heard playback are recorded separately.

### Interpretation of the cDSP probe error

Source review of upstream Linux v7.2.6 shows that `rpmsg_dev_probe()` reports `-ENOMEM` (`-12`) whenever `rpmsg_create_ept()` returns NULL, before calling the FastRPC driver probe. The GLINK implementation can return NULL after a channel-open timeout as well as other failures. Therefore this log does **not** establish RAM exhaustion or a missing reserved-memory allocation. Both cDSP QRTR and FastRPC fail to create endpoints, which points to their shared messaging path; the exact Ubuntu-versus-Arch patch, DT or initialization difference is still unproven. Sources: [RPMsg core](https://github.com/gregkh/linux/blob/v7.2.6/drivers/rpmsg/rpmsg_core.c), [Qualcomm GLINK](https://github.com/gregkh/linux/blob/v7.2.6/drivers/rpmsg/qcom_glink_native.c).
