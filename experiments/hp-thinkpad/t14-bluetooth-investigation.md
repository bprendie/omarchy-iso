# T14s Bluetooth device-tree trial (2026-09-21)

The installed T14s runs `linux-aarch64 7.2.6-1` with BlueZ and Qualcomm
firmware installed, but has no HCI controller. The running board tree leaves
`uart14` (`serial@a98000`) disabled and has no Bluetooth child or WCN7850 PMU.
The physically working `oma_snap` kernel 7.0 tree has those nodes, along with
GPIO 214 for the WCN rail and GPIOs 116/117 for Bluetooth/WLAN enable. The
mainline Qualcomm QCP board tree uses the same WCN7850 circuit. Mainline T14s
currently omits it.

[`t14-bluetooth.dtso`](t14-bluetooth.dtso) restores only the T14s WCN7850
rails, PMU, pinctrl, UART and Bluetooth child. It is applied to the installed
7.2.6 T14s LCD DTB with `fdtoverlay`; the HP tree is untouched. The resulting
DTB compiled and has an enabled UART, `qcom,wcn7850-bt` child and
`qcom,wcn7850-pmu`. The installed kernel includes the Qualcomm WCN power
sequencer and HCI UART support. The T14s has `hmtbtfw20.tlv` and `hmtnv20`
firmware.

The installed machine has a separate **T14 Bluetooth trial** Limine entry.
Its UKI preserves the exact installed kernel and initramfs section hashes and
embeds only the patched T14s DTB. The original UKI remains unchanged. The
Limine default explicitly points to `Omarchy/linux-aarch64`; a one-shot boot
selection pointed to the trial. The owner booted it and entered the disk
passphrase. `bluetoothctl list` now shows the controller powered on; the kernel
reports completed QCA firmware setup, the owner sees nearby Bluetooth devices,
and Wi-Fi remains connected. Pairing and reconnect were still untested at that
trial stage.

The shared HP/T14 ISO candidate includes the live DTB and a board-scoped
package that installs the same DTB before Dragon's installed UKI build. The
package checks the base DTB hash and leaves a changed future kernel tree
untouched. Pairing and reconnect are part of the owner's post-flash test.

After the owner clean-installed from that ISO, the normal Omarchy boot entry
exposed the patched UART/PMU nodes and a powered HCI controller. The package
`omarchy-hw-t14s-bluetooth-experimental 0.1-1` is installed, firmware setup
completed, and an eight-second scan discovered nearby devices while Wi-Fi
remained connected. The owner paired Nothing Ear (3) headphones on the fresh
install, but they were later disconnected and music continued on the speakers.
`bluetoothctl connect 2C:BE:EE:4A:CA:DE` established the audio connection and
exposed an A2DP sink in PipeWire. Selecting that sink and moving the active mpv
stream produced audible headphone playback, confirmed by the owner. The
Bluetooth SPA plugin and A2DP profile were already present; no additional
package or board-tree change was needed for playback. Automatic reconnection
and routing after a reboot remain untested.

The first software reboot after Bluetooth/headphone testing was slow but
eventually completed. NetworkManager and `wpa_supplicant` timed out during
shutdown, while `ath12k_wifi7_pci` reported pending TX packets. The owner saw
`qmi failed to send wlan mode off` on the console after the persisted journal
ended. The T14 then booted with working Wi-Fi. This is a reboot quality-of-life
regression candidate, but one observation does not establish whether the new
Bluetooth device-tree wiring, Wi-Fi driver, firmware, or their shutdown ordering
caused it. Retain the original DTB for a controlled comparison.
The slow reboot reproduced with no Bluetooth device connected: the T14 was
unreachable for about 5 minutes 18 seconds. Both network services again timed
out on shutdown, and ath12k reported pending packets plus peer-key removal
timeout `-110`. Wi-Fi recovered on the next boot. This rules out an active
headphone connection as a necessary trigger, but does not yet isolate the
board power sequence from the Wi-Fi driver or firmware.

The current T14 DT has no `wifi@0` child under `pcie4_port0`, so its WCN7850
PMU exposes a Bluetooth consumer but no Wi-Fi consumer. The HP's running tree
has a `wifi@0` child and a PMU device link; the upstream QCP WCN7850 tree also
declares the Wi-Fi function with PMU regulator supplies. A separate
[`t14-bluetooth-wifi-pmu.dtso`](t14-bluetooth-wifi-pmu.dtso) candidate adds that
function to the T14's experimental overlay. It compiles, applies to the exact
7.2.6 base DTB, and leaves the previously shipped overlay reproducible. This
was a structural hypothesis, not a validated reboot fix. The separate boot
entry allowed a physical test without changing the normal entry.
The optional installed Limine entry is `Omarchy/t14-wifi-pmu-trial`; the normal
entry remains the default. Its UKI has the same kernel and initramfs section
bytes as normal and the candidate DTB, with Secure Boot disabled on this host.
On the first physical selection of the PMU trial, the owner observed a full
freeze with no keyboard response. The machine was unreachable by ping or SSH.
The candidate failed; do not promote its Wi-Fi child or package it into an ISO.
The owner booted the normal entry after forcing the frozen machine off. No
separate journal or pstore record from the failed trial exists. The trial UKI
and Limine entry were removed; the normal UKI and installed DTB hashes are
unchanged, and Wi-Fi works on the normal tree. The Wi-Fi PMU child remains a
rejected deployment candidate. The trial also replaced normal `.dtbauto`
selection with a single `.dtb` section in a rebuilt UKI. This confounds the
physical test: it does not isolate or disprove the Wi-Fi PMU links. Preserve
normal UKI construction in any future controlled comparison.

Source references: [upstream QCP WCN7850 wiring](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/x1e80100-qcp.dts),
[upstream T14s tree](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/x1e78100-lenovo-thinkpad-t14s.dtsi),
[WCN power sequencer](https://github.com/torvalds/linux/blob/master/drivers/power/sequencing/pwrseq-qcom-wcn.c).
