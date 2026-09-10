# Tested hardware

Add yourself: run `xgm-egpu report` while the eGPU is active, paste the row
here in a pull request, or into an issue titled `hardware: <host> + <dock>`.
Set `DOCK="..."` in `/etc/xgm-egpu.conf` and the report fills that column in.
"Dies at stage N" rows are as welcome as working ones.

Result column: **works** (survival watch passed and the card is usable),
**dies** (link drops after the driver binds; say when), **no enumerate** (EC
accepts the write, nothing appears on the bus), **blocked** (say where).
Mode: *render* (`drm nokms`, games via PRIME offload) or *display* (monitor
on the eGPU's ports).

| Host | Dock | GPU | Distro / kernel / driver | Result | Link | Mode | Date | Notes |
|---|---|---|---|---|---|---|---|---|
| ROG Flow X13 GV301QH (BIOS 415) | DIY osy Lite v0.6.1, ALC04-S40EIA-00 instead of I-PEX CABLINE-VS | RTX 3060 (GA104, 10de:2487) | CachyOS, 7.2.3-1-cachyos, NVIDIA 580.178.04 | works | 8.0 GT/s x8 | render + display; monitor on the eGPU HDMI via `desktop pin --outputs` | 2026-09-09 | `go`; needs `pcie gen3` + `--freeze-link`, dies ~10 s after bind without them ([FINDINGS §8](FINDINGS.md#8-the-ten-second-link-death--rtd3-was-not-the-cause)). ~40 W idle |
| ROG Ally (RC71L) | DIY osy | RTX 3080 | CachyOS | in progress | | | 2026-09 | BAR0 / bridge window: `pci=realloc=on pci=hpmmiosize=128M` on the kernel line |
| ROG Ally RC71L (BIOS RC71L.342) | *(dock not yet reported)* | RTX 5070 (Blackwell) | CachyOS Handheld, 7.2.3-1-cachyos-deckify, NVIDIA 610.57.04 | works | 16.0 GT/s x4 (Gen4 x4, the Ally's XGM port) | desktop mode | 2026-09-10 | Reported on the osy Discord by armenazizbek (`xgm-egpu report`). No internal dGPU, so no eject. In the gamescope "Gaming Mode" session the eGPU's monitor stays dark: gamescope drives only the GPU it composites on; see the README's Gaming Mode section for the two-variable fix (untested) |

## Dock revisions and connectors

The reference build is the most marginal configuration that exists: a DIY
board with substituted connectors on the oldest Flow. If you have an official
dock, or I-PEX connectors, you are strictly closer to the happy path and may
need none of the link-freezing. Please say which in your row.

## Known per-model facts (from the osy Discord, unverified here)

- Flow: power the XG Mobile up before connecting the laptop's own PSU, or the boot crashes even with the PC off (Faith).
- Cold boot with the eGPU attached can leave the link at PCIe 1.1 until the XG Mobile is power-cycled (SR20GODSMOTOR). Probably the same retrain problem seen from Windows.
- Ada/Blackwell cards reportedly cause a hard-shutdown hang that PCIe 4.0-or-lower cards do not (Semih). The reference card is Ampere.
