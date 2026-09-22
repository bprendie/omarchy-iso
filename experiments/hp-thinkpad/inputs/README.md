# Firmware input provenance and rebuild gap

The source checkpoint preserves recipes and exact bytes' checksums, not vendor
binary redistribution permission. The HP/Lenovo packs were extracted locally;
no Windows installer or BIOS capsule was executed. The existing preparation
script still requires retained oma_snap package archives. This document records
how their selected payloads were obtained, so that dependency can be replaced
without silently selecting different firmware.

## HP GPU and DSP

- Source: https://ftp.hp.com/pub/softpaq/sp162501-163000/sp162865.exe
- Metadata: https://ftp.hp.com/pub/softpaq/sp162501-163000/sp162865.cva
- Pack: SP162865, 7700.1 revision E pass 5.
- Archive SHA256: `215ec14bef7090660a5e868f22e84fbeea2ee1139706a0615bfda62948417e08`.

Extract with 7z, without executing the archive. Under `src/Driver/`, use:

| Input directory | Files |
| --- | --- |
| `qcdx8380` | `qcdxkmsuc8380.mbn` |
| `1ADSP_7700_0711_hamoa` | `qcadsp8380.mbn`, `adsp_dtbs.elf` |
| `1qcnspmcdm_ext_cdsp8380_7800` | `qccdsp8380.mbn`, `cdsp_dtbs.elf` |

Destination is `/usr/lib/firmware/updates/qcom/x1e80100/hp/elitebook-ultra-g1q/`.
The retained HP input notes explicitly say redistribution permission was not
established. Obtain the original vendor terms before hosting these binaries.

## Lenovo cDSP replacement pair

- Source: https://download.lenovo.com/pccbbs/mobiles/n42qq23w.exe
- Metadata: https://download.lenovo.com/pccbbs/mobiles/n42qq23w_2_.xml
- Archive SHA256: `9ec6ae30abd40f56aa6b3b0b480686acbbb72ff12ba186b3f45f61fc924ef4f3`.

Use `innoextract`, never execute the installer. Selected directory:
`code$GetExtractPath$/N42QQ23W/N42QG16W/Core_drivers/qcnspmcdm_ext_cdsp8380`.
Copy `qccdsp8380.mbn` and `cdsp_dtbs.elf` over the base Lenovo firmware in
`/usr/lib/firmware/updates/qcom/x1e80100/LENOVO/21N1/`.
Redistribution terms for this exact pair remain to be established.

## Lenovo base firmware

The retained base package is `oma-snap-firmware-ubuntu 20260319.217ca6e4-2`.
It was assembled from the firmware in `casper/minimal.squashfs` of
`https://cdimage.ubuntu.com/releases/26.04/release/ubuntu-26.04.1-desktop-arm64.iso`.
The retained bootstrap manifest pins that ISO to
`c54d196489d3c867975fb3bbb72ca52ec2e137456e305481f81096304e4d2517`.
The original ISO is no longer in this checkout and the URL has not been revalidated
for this checkpoint. Do not substitute another release without comparing payloads.

Original extraction used xorriso to extract `/casper`, then unsquashfs on
`minimal.squashfs` for `usr/lib/firmware` and `usr/share/doc/linux-firmware*`.
Select the `qcom/x1e80100/LENOVO/21N1` files, decompress `.zst` files, retain the
T14 topology alias, and replace the cDSP pair as above. `t14s-files.sha256` lists
exact final payloads. Preserve the source Qualcomm graphics/misc/wireless copyright
notices and resolve per-file terms before binary redistribution.

## Audio topology and HP UCM

The HP topology was built from BSD-3-Clause AudioReach sources at
`e7b20b2b16cdda18eb8ae143c8d95c4815c0288e`:
https://codeload.github.com/linux-msm/audioreach-topology/tar.gz/e7b20b2b16cdda18eb8ae143c8d95c4815c0288e

Archive SHA256: `bce3f22893decde37a810ed17ac690abc9c9fd39e7417021abc37e925cb1c82e`.
Run m4 with the source directory as its include path on
`X1E80100-LENOVO-Thinkpad-T14s.m4`, then `alsatplg -c` on the generated text.
Output topology SHA256:
`aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5`.
Install as `qcom/x1e80100/X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin` and carry
`LICENSE.BSD-3-Clause`. HP UCM generation is in `../prepare-packages.py`; it checks
three exact ALSA UCM source hashes before applying the DMIC2 change.

## Manifests and next reproducibility step

`retained-packages.sha256` identifies the four local package archives consumed
by `prepare-packages.py`. These are package-container hashes, not substitute
checksums for upstream downloads. `hp-files.sha256` and `t14s-files.sha256` identify
the final firmware files independent of package metadata.

A public rebuild needs a fetch/extract stage for these pinned inputs, verification
of the final file manifests, and a preparation mode that consumes those verified
files instead of private package archives. It also needs the staged-root ISO
assembly converted into a clean build. Neither is claimed complete here. Vendor
URLs were recorded from retained provenance; this checkpoint did not redownload
or rebuild their contents. No QNN SDK or proprietary inference runtime is included.
