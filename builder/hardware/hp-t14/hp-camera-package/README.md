# HP EliteBook Ultra G1q RGB camera candidate

This package is pinned to the Arch Linux ARM `linux-aarch64` 7.2.6-1 kernel and
the matching `linux-aarch64-headers`. It supplies the OV05C10 V4L2 sensor module
and an exact-hash-guarded board DTB. The DTB uses the kernel's integrated
X1E80100 CAMSS/CSIPHY ABI. The installed system's normal kernel/UKI update flow
remains responsible for boot publication.

The OV05C10 driver comes from Intel's GPL-2.0 IPU6 driver at commit
`71bddb5158fb7f0bd244ad7aa6b2efab024531a7`. It retains Intel attribution.
Local changes add OF matching and HP power sequencing, and correct runtime PM
handling for VBLANK writes. The HP board wiring was recovered from HP's camera
resource tables and physically validated on an earlier 7.0 kernel: CCI1 bus 1,
address `0x10`, GPIO237 reset, GPIO50 supply enable, MCLK4 at 19.2 MHz,
PM8010 LDO3_M at 1.8 V, and CSI4 with two lanes. No proprietary camera binary
is part of this package.

A new kernel DTB hash is not overwritten automatically. Rebuild and revalidate
the sensor module and board overlay against that kernel before updating the pin.
The current Dragon 7.2.6 camera candidate has passed only a static DTB overlay
and module build check. It needs physical enumeration and bounded frame capture.
