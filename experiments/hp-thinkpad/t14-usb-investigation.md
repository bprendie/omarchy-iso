# T14 installer USB investigation — 2026-09-21

IMG_0398 shows linux-aarch64 7.2.6-1 successfully detecting the internal NVMe
and its partitions, plus the I2C keyboard and touchpad. No USB mass-storage
block device appears. Archiso waits 30 seconds for the ISO UUID, searches
the NVMe partitions, and opens its rescue shell. This is distinct from the
oma_snap 0.2.2 installed-system NVMe failure.

The screenshot's device-link warning is not sufficient to diagnose the cause:
the running HP's journal contains the same a600000/a800000 PMIC GLINK warnings.
Read-only HP checks confirmed those USB controllers are bound to dwc3-qcom.
No remote configuration or device state was changed.

The packaged kernel has USB storage, UAS, SCSI disk, DWC3, xHCI and major
Qualcomm USB PHY drivers built in. The tested initramfs contains the NXP
PTN3222 and Synopsys eUSB2 PHY modules. Missing storage modules do not explain
this evidence. Keyboard enumeration does not prove functioning input.

## Verified baseline differences

The original 0.1.2 ISO's actual GRUB configuration has no DSP blacklist.
Its embedded LCD DTB was extracted for comparison: it uses the older nested
Qualcomm USB binding (for example, a8f8800 glue around a800000 DWC3). Dragon's
matched 7.2 kernel/DT uses the flattened qcom,snps-dwc3 layout. Both describe
the enabled external controllers as host-mode devices. Do not transplant
the old tree into the new kernel as an assumed fix.

Dragon's live entry explicitly blocks qcom_q6v5_pas. Its normal delayed DSP
startup helper is limited to Yoga Slim 7x and does not run until userspace.
The boot-only A/B image removes that blacklist in its default entry and
retains the previous behavior as a second visible menu entry. Kernel, DTs,
initramfs, root filesystem and package set are identical to the bootdiag ISO.
No claim of a DSP or controller regression is justified before this comparison.

The existing report's `tr: not found` is a diagnostic defect; it prevents
printing the model, not USB discovery. This A/B image intentionally retains
the same initramfs so only the DSP boot policy changes.

Upstream ISO dragon was fetched before investigation and remains f97a775.
Build using build-t14-dsp-test.sh in the native builder with the repo at /repo.
Copy to ~/ISOs and stop. Physical confirmation is required; no USB write,
kernel rollback or changes to the HP are included.

## Physical A/B outcome

The owner confirmed that the DSP-enabled default entry in
`omarchy-dragon-t14-dsp-test-2026.09.21-aarch64.iso` completes rootfs loading
and reaches the installer on the T14, then completes installation and installed
boot. The owner subsequently confirmed the same image reaches the installer
on the HP. The HP was not reinstalled for this live-policy comparison.

This supports early DSP startup for these two tested boards. It does not
establish the detailed USB mechanism, every physical port, or safety of a
global blacklist removal across other Snapdragon machines. Diagnostic verbosity
was visible on both and is a presentation follow-up for the integrated image.
