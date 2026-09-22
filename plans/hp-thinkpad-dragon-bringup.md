# HP and ThinkPad bring-up on Dragon

## Goal and current baseline

Make the HP EliteBook Ultra G1q and Lenovo ThinkPad T14s Gen 6 LCD work on
Dragon's Arch Linux ARM kernel, hardware packages, device-tree selection,
Quattro installation and installed Limine boot. Develop shared fixes once;
validate each board separately. Keep hardware evidence and vendor inputs local.

The experimental ISO `omarchy-dragon-hp-thinkpad-2026.09.16-aarch64.iso` boots and
installs on the HP. Installed HP Wi-Fi and Bluetooth work. HP ADSP and cDSP load;
ALSA and PipeWire expose a speaker, but the owner hears no audio. `cam -l` lists
no cameras. The cDSP FastRPC endpoint fails to probe (`-12`) and there is no
`/dev/fastrpc-cdsp`. ThinkPad behavior on this Dragon ISO is **unmeasured**.
The owner previously validated audio, RGB camera and a small QNN HTP graph on
oma_snap's Ubuntu kernel, subject to the qualifications in its validation notes.

Do not turn a firmware load, detected ALSA card, detected camera node or
compiled module into a hardware PASS. Record the kernel, DTB, firmware hashes,
runtime versions, device model and exact test for every result. Existing failed
or untested states remain visible until replaced by physical evidence.

## Phase 0 — Freeze evidence and identify shared causes

| Shared work | HP lane | ThinkPad lane | Exit gate |
| --- | --- | --- | --- |
| Inventory Dragon kernel config, selected DTB, installed packages, firmware paths/hashes, initramfs, boot args and DSP/FastRPC/camera logs; compare with the working oma_snap set. Capture a per-board matrix with `works`, `fails`, `untested` and a link to raw local logs. | Preserve the current installed HP audio, camera and NPU logs. Confirm which exact firmware and UCM files the running kernel loads. | Boot/install the same image on the ThinkPad when hardware is available; collect the same inventory. Record the keyboard/TrackPoint cable state separately. | Both boards have inventories, or the ThinkPad is explicitly marked blocked by physical availability. Differences are assigned to kernel/DT, firmware, ALSA/UCM, userspace or integration. |

Use oma_snap's physical results as reference, not as a Dragon pass. A ThinkPad
lane can proceed in source/package review while its physical lane waits. Avoid
repeating firmware extraction, hashes, harnesses or test scripts per board.

## Phase 1 — Establish reusable Dragon hardware packages

| Shared work | HP lane | ThinkPad lane | Exit gate |
| --- | --- | --- | --- |
| Make small package recipes for common early modules/test utilities and separate board firmware/config. Keep exact DMI selection in `configs/aarch64/platforms.json`. Pin source revisions and hashes; record redistribution terms. Confirm packages install in both live and target systems and survive kernel/package updates. Follow the team's package recipe and kernel ownership rather than adding an alternate boot/kernel manager. | Package HP GPU/ADSP/cDSP files, tested topology and DMI-name UCM mapping. | Package Lenovo GPU/ADSP/video/topology and the **matched** cDSP firmware pair validated by oma_snap. | Package contents, initramfs membership, selected DTB, offline closure, and installed-root update hooks pass on both models. No cross-board file overrides or generic DMI matches. |

The first ISO already contains experimental versions of these packages. Audit
those recipes and the pending Dragon team firmware extraction/kernel metadata
work before proposing replacements. Preserve Dragon's UKI and Limine flow.

## First hardware handoff — pause after the earliest coherent ISO

As soon as Phase 0 inventory and Phase 1 package closure are sufficient to
assemble a boot candidate, build **one proposed ISO for both machines**. Verify
its package contents and boot image, then stop work and give the owner only its
path and the known limitations. The owner installs it on the HP and ThinkPad
and provides SSH access to each. Do not wait for audio, camera or NPU fixes to
make this handoff: fresh Dragon evidence from both installed machines is the
input to Phases 2–5. Do not write USB media, run a VM, change installed systems
or proceed to later phases while awaiting the owner's physical tests.

The handoff cannot claim a ThinkPad hardware pass before its first Dragon boot.
The HP remains an audio/camera/NPU diagnostic candidate at this gate.

## Phase 2 — Audio on both boards

| Shared work | HP lane | ThinkPad lane | Exit gate |
| --- | --- | --- | --- |
| Compare topology, ALSA routing, UCM selection and DSP messages with oma_snap. Use the same bounded playback/capture checks and log template. Fix a common kernel or package cause once. | Trace the current speaker PCM from `wpctl` through UCM and mixer to the backend. Resolve the audible failure; check speaker, headset and microphones individually. The observed HDMI PCM error is a clue, not proof of the speaker cause. | Run the same endpoint checks on installed Dragon. Do not infer a pass from the earlier oma_snap owner report. | Owner hears speaker and headset playback; microphone capture works; reboot and a package/kernel update retain the result. Record any endpoint still untested. |

## Phase 3 — RGB cameras on both boards

| Shared work | HP lane | ThinkPad lane | Exit gate |
| --- | --- | --- | --- |
| Keep libcamera, IPA, PipeWire and GStreamer userspace in model packages. Validate the Dragon CAMSS/CCI binding, graph and kernel configuration before shipping modules/DT changes. Use one capture script with board-specific sensor identity; do not save frames by default. | Port the validated OV05C10 driver correction and HP wiring (CCI1 master 1, address `0x10`, reset/supply GPIOs, MCLK4, CSI4 two lanes) to Dragon's selected DT and kernel. The Ubuntu late-CSI-PHY helper is not presumed compatible. | Check whether Dragon's selected DT exposes OV02C10 and a complete CAMSS graph. If so, test the existing kernel path and userspace first; patch only observed gaps. | Per board: `cam -l`, two bounded 10-frame direct captures, 10-frame PipeWire capture, owner preview and repeat after reboot. Record quality, privacy LED, IR and suspend behavior separately. |

The first Dragon ISO contains camera userspace but no HP sensor driver/board
graph. The driver compiled against Dragon's headers; that is not a capture pass.

## Phase 4 — cDSP/FastRPC and NPU on both boards

| Shared work | HP lane | ThinkPad lane | Exit gate |
| --- | --- | --- | --- |
| Compare Dragon's cDSP FastRPC DT, kernel config/patches, probe order and memory allocation with the working oma_snap kernel. Resolve endpoint creation before adding NPU runtime. Reuse one local, on-demand calculator/validator/QNN harness; keep SDK binaries out of the public ISO and avoid a permanent polling daemon. | Fix the current `-12` probe and obtain a working `/dev/fastrpc-cdsp`; test with the matching HP cDSP firmware and shells. | Test the Lenovo matched cDSP firmware **and its matching shells/libraries**; do not substitute the previously shipped stock firmware for the validated pair. | Per board: cDSP boots, FastRPC calculator returns sum `499500` and max `999`, DSP validator passes, and explicit HTP backend ID 6 executes the four-element ReLU to `[0,0,0,3]`. Verify cleanup and reboot; label performance and sustained workloads untested. |

NPU tests in oma_snap ran with a separate local runtime and privileged FastRPC
nodes. For Dragon, decide device access policy after the transport is stable.
Avoid broad permissions merely to make a test pass.

## Phase 5 — Boot, input, power and update regression

| Shared work | HP lane | ThinkPad lane | Exit gate |
| --- | --- | --- | --- |
| Rebuild the normal Dragon ISO and test live boot, installed unlock, installed boot, update/reboot, firmware discovery and rollback. Check Wi-Fi, Bluetooth, display, brightness, battery/charging, suspend/resume, and audio/camera/NPU after resume. Measure battery cost under matched conditions as described in oma_snap validation and `~/weazl_skill.md`; report uncertainty and minutes per full charge only from controlled samples. | Recheck visible unlock, Fn/media keys and keyboard backlight; these were unresolved under oma_snap. | Recheck TrackPoint and keyboard backlight after the replacement keyboard/cable condition is known. | Both machines meet an agreed hardware matrix, with remaining limitations explicit. No regression in Dragon's default boards or installer/kernel update path. |

## Phase 6 — Reviewable Dragon contributions

Split the finished work into narrow changes: exact board profiles; reusable
hardware package recipes and provenance; kernel/DT fixes for observed gaps;
camera integration; and a local validation recipe. Link each change to its
physical evidence and state the tested kernel/firmware versions. Coordinate
with the Dragon team's pending package work before submitting overlapping
recipes. Do not publish vendor firmware, private logs or SDK payloads without
an explicit distribution decision.

At each phase, advance the shared implementation and both board lanes together.
One board passing never closes the other lane. A physical test that is not yet
possible stays `untested` and does not block source/package preparation.
