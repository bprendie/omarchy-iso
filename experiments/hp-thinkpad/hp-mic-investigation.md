# HP internal microphone on Dragon — September 21, 2026

The installed HP EliteBook Ultra G1q boots Dragon kernel 7.2.6 and plays through
its speakers. Its default internal-mic source opens but produces exact zeros.
The T14s on the same kernel and ALSA UCM version produces live microphone
samples. The owner confirmed T14 microphone meters and provided music near both
machines for the comparison.

The HP package had aliased its UCM to `LENOVO-T14s.conf`, whose internal-mic
sequence selects `VA DMIC MUX1 = DMIC1`. During a bounded HP test, the original
PipeWire route returned only zeros. Selecting `DMIC2` on that mixer control
while keeping the other settings produced sustained samples from the physical
music source: one three-second PipeWire capture had 105,673 nonzero samples on
its active channel and RMS 1090.5; the T14 baseline was nonzero on both channels.
The active HP device tree defines four VA DMIC routes and both DMIC pin groups.
Changing both muxes to DMIC2/DMIC3 yielded only switching transients followed
by silence, so that is not the proposed route.

The candidate package generates an HP-only UCM profile from the hash-pinned
ALSA UCM 1.2.16.1 T14 files, changing only the second internal-mic mux from
DMIC1 to DMIC2. In a temporary HP system-file trial, WirePlumber published
the speaker, internal-mic and headset nodes. PipeWire capture contained 49,772
nonzero samples on one channel (RMS 150.4) while music played; the other channel
remained silent. The original HP UCM aliases and mixer settings were restored
after the trial. No reboot was performed.

A trial to present the source as mono via `plughw` and `CaptureChannels 1`
parsed in ALSA but caused WirePlumber to publish no audio nodes. That variant
was discarded. The proposed ISO keeps the existing two-channel capture PCM,
with one active channel. The owner still needs to check meter response, speech
intelligibility, and speaker/headset routing on the installed candidate. Do not
claim a full microphone pass before that test.

## Fresh combined-ISO install

The HP clean-installed from the combined HP/T14 ISO and booted the normal
`7.2.6-1` kernel. `omarchy-hw-hp-experimental 0.3-1` and the DMIC2 include are
installed. A three-second 48 kHz PipeWire recording contained 128,158 nonzero
samples on channel 1 (RMS 349.5); channel 2 remained exact zero. The recording
was measured and deleted. The owner then confirmed that the fresh install's
internal-mic meter moves while speaking and a short recording sounds clear.
Usable speech capture passes; the silent second channel remains documented.
