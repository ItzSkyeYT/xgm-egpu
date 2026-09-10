# xgm-egpu

Use an ASUS XG Mobile eGPU on an ordinary Linux distribution: ROG Flow and
ROG Ally hosts, official docks and DIY ones built from
[osy/XG_Mobile_Station](https://github.com/osy/XG_Mobile_Station).

A shell script, two config files, and the write-up of why the obvious
approaches hang or kill the machine. Not a SteamOS plugin: no Decky, no Gaming
Mode, no immutable-root machinery. On SteamOS or Bazzite use
[Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager) instead.

## Status

**Working, including a monitor on the eGPU's own ports.** On the reference
machine (Flow X13 GV301QH, DIY osy Lite v0.6.1 dock, RTX 3060, CachyOS) the
card runs at PCIe Gen3 x8 with the driver bound, zero link errors,
`nvidia-smi` and PRIME render offload working, and with `go --display` plus
`desktop pin --outputs` the desktop extends onto a monitor on the eGPU's
HDMI (2026-09-09 23:30). Games render on the eGPU and display on either
screen. `off` must run from a TTY in that mode, because kwin holds the card.

### What works, on what

| Host | Dock | GPU | Result | Modes that work | What it needed |
|---|---|---|---|---|---|
| ROG Flow X13 GV301QH (2021, AMD 5900HS) | DIY osy Lite v0.6.1, ALC04-S40EIA-00 instead of I-PEX CABLINE-VS | RTX 3060 (GA104, 10de:2487) | **works**, PCIe Gen3 x8, zero AER | render offload to the laptop screen (`go`); full display path with a monitor on the eGPU's HDMI (`go --display` + `desktop pin --outputs`) | `install-rules` (RTD3 off), `drm nokms` or `drm nofbdev`, `pcie gen3`, `--freeze-link`; ~40 W idle |
| ROG Ally RC71L | DIY osy | RTX 3080 | in progress | | `pci=realloc=on pci=hpmmiosize=128M` on the kernel line for the BAR window |
| ROG Ally RC71L (BIOS 342) | *(dock not reported yet)* | RTX 5070 (Blackwell) | **works**, PCIe Gen4 x4, NVIDIA 610.57 | desktop mode on CachyOS Handheld; Gaming Mode needs the [gamescope variables](#gaming-mode-gamescope-sessions-bazzite-chimeraos-steamos-style) | reported on the osy Discord, 2026-09-10; no internal dGPU, so no eject |
| *your machine* | | | | | `xgm-egpu report` prints a row - see [HARDWARE.md](HARDWARE.md) |

Full details, dock revisions and the per-model notes from the osy community
are in [HARDWARE.md](HARDWARE.md); a row there, working or not, is the most
useful thing you can add.

The whole hunt, cause included, is in [FINDINGS.md](FINDINGS.md). The one-line
version: the NVIDIA driver retrains the PCIe link about ten seconds after
init, when the GPU leaves P0, and a DIY link cannot complete a retrain at
Gen3. The fix removes every reason to retrain.

See [HARDWARE.md](HARDWARE.md) for what has been tested, and add your machine.

## Read this first

**[docs/RECOVERY.md](docs/RECOVERY.md).** `egpu_enable` is persistent EC state:
it survives reboots and forced power-offs. If it commits and no eGPU
enumerates, you have no discrete GPU, and with the dock attached the machine
may not boot. Recovery takes five minutes if you know it before you need it.

## Quick start

```sh
git clone https://github.com/ItzSkyeYT/xgm-egpu
cd xgm-egpu
sudo ./install.sh --link       # symlink into /usr/local/bin so edits are live
xgm-egpu detect                # read-only: what it worked out about your machine
xgm-egpu status                # read-only: egpu_connected must be 1
```

Then, dock connected and locked, laptop on mains:

```sh
sudo xgm-egpu go
```

`go` does everything in order and says which stage it is in: it checks the
three persisted settings in the loaded driver (RTD3 off, `nvidia_drm
modeset=0`, PCIe Gen3 allowed) and writes and reloads whatever is missing on
the first run; refuses if your compositor is holding the internal GPU; runs
the activation that works (`on --no-kms --freeze-link --force-kill`); then
proves the result with `nvidia-smi` at Gen3 and `glxinfo` run as you inside
your session, naming the eGPU. The EC write can take up to two minutes; slow
is not stuck.

Games: Steam launch options `prime-run %command%` (add `mangohud` to see the
GPU name in the overlay; native Wayland games need `SDL_VIDEODRIVER=x11`).
When done: `sudo xgm-egpu off`. Every setting persists; the activation is
one command per boot.

## What the working configuration is

| Piece | What it does | Why |
|---|---|---|
| `install-rules` | RTD3 off, runtime PM pinned on the root port and the eGPU | RTD3 drops the link 10 s after idle; the port must never autosuspend |
| `drm nokms` | `nvidia_drm modeset=0`: the eGPU gets a render node only | no display engine bring-up; PRIME offload still works through a system-memory path |
| `pcie gen3` | `NVreg_EnablePCIeGen3=1` | the driver otherwise treats Gen3 as forbidden on an unrecognised platform and pulls the link down |
| `on --freeze-link` | clocks locked at max (GPU stays in P0), PCIe autonomous-speed-disable bits on both ends | the idle-time generation downshift is the retrain that killed every run |
| `on --no-kms` seal | `/dev/null` bind-mounted over `/dev/nvidia-modeset` for the run | kwin and every PRIME client otherwise bring the display engine up themselves |
| `desktop pin` | `KWIN_DRM_DEVICES` pinned to the laptop's card | kwin otherwise holds the internal dGPU and has to be killed for the eject |

Cost: about 40 W idle on the dock, because the GPU never leaves P0.

**Render-only vs display mode, measured** (Watch Dogs 2, High, 1536×960
internal, Flow X13 + RTX 3060): render-only presents through a system-memory
path with no GPU fences, so CPU and GPU serialise: 27 fps, 49 ms frames, the
GPU at 58 W reading "96 % busy" while spin-waiting. Display mode restores
the fences: 41 fps (61 average), 25 ms frames, the GPU at 70 W and 60-70 %
busy, PCIe at ~1.3 GB/s of 6.5. Beyond that the laptop's CPU is the limit
(76-85 % at 94 °C). Use `go --display` for games if you can live with `off`
from a TTY; `go` (render-only) is the simpler mode for compute.

## Using it from the desktop

`on` must release the internal dGPU, and the compositor is what usually holds
it. Two mechanisms keep your session alive:

- `xgm-egpu desktop pin` (no sudo, then log out and in once) keeps kwin off
  every NVIDIA device. It validates the file the way Plasma sources it before
  you log out, and prints the rollback (`desktop unpin` from a TTY).
- Whatever `--force-kill` has to close (a browser with GPU acceleration,
  typically) is started again when the run ends, as you, into your session.

From a TTY, `go`/`on`/`off` stop the display manager before the release and
start it again when the run ends, success or not, so you land on a login
screen rather than a dead console (`--keep-desktop` skips that). `go` checks
for a compositor holding the GPU before it touches anything.

## Gaming Mode (gamescope sessions: Bazzite, ChimeraOS, SteamOS-style)

A gamescope session composites on one GPU and drives only that GPU's
outputs, so with the eGPU active the image stays on the internal panel and
a monitor on the eGPU's ports goes dark. gamescope opens the DRM device of
whichever GPU it composites on, and the session script reads two variables
from `~/.config/environment.d/*.conf`:

```sh
# ~/.config/environment.d/egpu.conf
VULKAN_ADAPTER=10de:2487        # the eGPU's vendor:device id, from: lspci -nn | grep -i nvidia
OUTPUT_CONNECTOR=HDMI-A-2,*     # the eGPU's connector first, from: ls /sys/class/drm (while it is on)
```

Bring the eGPU up in display mode first (`xgm-egpu go --display`; gamescope
needs the KMS node), then switch to Gaming Mode. gamescope then holds the
eGPU, so `off` must run from a TTY. Untested here (the reference machine
runs KDE); the symptom was reported by an RTX 5070 user on the osy Discord.

## Commands

Everyday: `go`, `off`, `status`, `detect`, `preflight`, `logs`, `report`,
`link`. Settings: `install-rules`, `drm`, `pcie`, `gsp`, `desktop`,
`reload-driver`. Research: `on` with its options, `bind`, `watch`, `capture`,
`link-speed`, `ec`. `xgm-egpu --help` documents every one; each has a
`--dry-run`.

Every `go`/`on`/`off`/`bind`/`reload-driver` writes its complete output to
`/var/log/xgm-egpu/<time>-<command>.log`, and the survival watch saves the
kernel log beside it. `xgm-egpu logs` lists them; after any failure,
`xgm-egpu logs show` is what to paste into an issue.

## Other machines

Nothing to configure: the internal dGPU, its device ID and the PCIe root port
the XG Mobile shares lanes with are autodetected from sysfs (`xgm-egpu
detect` shows the reasoning). Hosts without an internal dGPU (ROG Ally) are
the easier case: nothing shares the lanes, so activation triggers no eject.
Detection only refuses to guess when a host has several empty hotplug slots
and no internal dGPU; then one line in `/etc/xgm-egpu.conf` (`ROOT_PORT=`)
or `--root-port` settles it. [docs/PORTING.md](docs/PORTING.md) explains the
derivation. Detection getting a machine wrong is a bug worth an issue.

## Contributing

The most valuable contribution is a row in [HARDWARE.md](HARDWARE.md). Run
`xgm-egpu report` while the eGPU is active; it prints the row and the details
for an issue. "It died at stage 3" is as useful as "it works". See
[CONTRIBUTING.md](CONTRIBUTING.md).

## Open questions

- Whether the idle PCIe downshift can be prevented without locking the
  clocks (a registry key rather than P0 forever, which costs ~40 W idle).
- Whether the idle downshift can be prevented without locking clocks (a
  registry key rather than P0 forever).
- Official docks: the reference machine is the most marginal build that
  exists. An official dock may need none of `--freeze-link`.

## Documentation

- [docs/RECOVERY.md](docs/RECOVERY.md): unbootable machine, wedged terminal, stuck EC state
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md): symptom, cause, fix
- [FINDINGS.md](FINDINGS.md): the reverse-engineering, the dead ends, the resolution
- [docs/PORTING.md](docs/PORTING.md): how detection works, deriving values by hand
- [HARDWARE.md](HARDWARE.md): tested hosts, docks and GPUs

## Credits

- [osy/XG_Mobile_Station](https://github.com/osy/XG_Mobile_Station): the DIY dock, and `Docs/ACPI_Annotated.asl` + `Docs/Software.md`, the primary sources for all of this.
- [stensmir/xg-mobile-linux](https://github.com/stensmir/xg-mobile-linux): first to show the sysfs write is all it takes on SteamOS.
- [Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager): the SteamOS/Bazzite implementation.
- Luke Jones and [asus-linux](https://asus-linux.org/): `asus-wmi` and `asus-armoury`.

## Maintenance and licence

Unmaintained by default: research published in case it helps, by someone with
one machine. Issues are read; fixes may be slow; forks are encouraged. MIT,
see [LICENSE](LICENSE).
