# xgm-egpu

Use an ASUS XG Mobile eGPU on an ordinary Linux distribution: ROG Flow and
ROG Ally hosts, official docks and DIY ones built from
[osy/XG_Mobile_Station](https://github.com/osy/XG_Mobile_Station).

A shell script, two config files, and the write-up of why the obvious
approaches hang or kill the machine. Not a SteamOS plugin: no Decky, no Gaming
Mode, no immutable-root machinery. On SteamOS or Bazzite use
[Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager) instead.

## Status

**Working, render offload.** On the reference machine (Flow X13 GV301QH, DIY
osy Lite v0.6.1 dock, RTX 3060, CachyOS) the card runs at PCIe Gen3 x8 with
the driver bound, zero link errors, `nvidia-smi` and PRIME render offload
working. Games render on the eGPU and display on the laptop screen. What is
not supported yet is a monitor on the eGPU's own ports (see [Open questions](#open-questions)).

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

- A monitor on the eGPU's own ports: every earlier death was the retrain,
  not the display engine, so `drm default` + `pcie gen3` + `--freeze-link` is
  the untested next experiment.
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
