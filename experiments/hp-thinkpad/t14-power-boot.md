# ThinkPad storage boot candidate — 2026-09-21

Fetch Dragon before starting each new integration/build task. This build fetched
omacom/omarchy-iso `dragon` at f97a775823c53069c003a4c620692cdb11fe7de0,
omacom/omarchy `dragon` at 66a33c339914cfa0e41ec1fce8f198ea779b8aea,
and omacom/omarchy-pkgs `master` at e40f5a5da918e8b923115ebb4c335b6c4828fefe.
The runtime uses a standalone `build/hp-thinkpad/omarchy-dragon-source` checkout;
the preceding Quattro checkout and its local modifications remain available.

## Physical evidence

Owner photos IMG_0394–0396 show the installed earlier prototype 0.2.2 boot running
7.2.0-18-qcom-x1e with the correct ThinkPad LCD model. Btrfs and the PCIe PHY
load, but neither NVMe devices nor the encrypted root mapping appear.
Both PCIe slot probes report `Failed to get the power sequencer`. The owner
confirmed that the initramfs has no drivers/power directory. The Concept
kernel payload contains drivers/power/sequencing/pwrseq-pcie-m2.ko.zst, but
the installed initramfs hook does not include that directory. This is a strong
boot-failure explanation pending a corrected physical boot, not a suspend diagnosis.

## Dragon integration

The refreshed Arch package index still selects linux-aarch64 7.2.6-1.
Its config disables POWER_SEQUENCING_PCIE_M2, but its shipped ThinkPad LCD DT
uses direct PCIe reset GPIOs and does not contain a pcie-m2 connector compatible.
Do not transplant the Concept DT or its ABI-specific modules into this kernel.

The common early package 0.2-1 now includes drivers/power/sequencing and
drivers/pci/pwrctrl in both live and installed initramfs builds. Final live
assembly requires NVMe, QMP PCIe PHY, WCN power sequencing and PCI power-control
modules. If a future ThinkPad DT requests an M.2 sequencer, assembly rejects
an initramfs missing that module. These checks complement Dragon's normal
device-tree UKI and installed Limine workflow.

The preceding refresh used the runtime's default Quattro branch, which lacked
the Qualcomm hardware setup calls. This candidate uses the actual Dragon
runtime branch, including those calls and its Qualcomm detector.

## Handoff

Build log: build/hp-thinkpad/t14-power-build.log. Copy the finished ISO to
~/ISOs and stop for owner installation. No VM or USB writing is requested.
Physical boot, SSH, audio, camera, NPU and suspend remain unverified on this
candidate. Existing HP firmware support is retained in the shared image.
