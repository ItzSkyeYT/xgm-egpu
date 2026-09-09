# xgm-egpu

Activating an ASUS XG Mobile eGPU on an ordinary Linux distribution - including
DIY docks built from [osy/XG_Mobile_Station](https://github.com/osy/XG_Mobile_Station).

Not a SteamOS plugin. No Decky Loader, no Gaming Mode, no immutable-root
bind-mount machinery. A shell script, two config files, and a long document
explaining why the obvious approach hard-hangs your machine.

## Status: partially working. Read this before you start.

This is a findings dump with a working tool attached, not a finished product.
It is published because the research is transferable even where the end result
is not, and because **the failure modes here will destroy your afternoon if you
meet them undocumented.**

| Stage | State |
|---|---|
| Activation (eGPU enumerates on the PCIe bus) | **Works** |
| NVIDIA driver binds, DRM nodes appear | **Works** |
| Link stays up under runtime power management | **Works**, with the shipped udev + modprobe rules |
| Link trains at PCIe Gen3 x8 | **Works** - earlier "Gen1 cap" was an idle-state reading, see [Findings](FINDINGS.md#pcie-link-speed) |
| Link survives **unbound** | **Works** - Gen3 x8 indefinitely, zero AER. The hardware is fine |
| Link survives with `nvidia` core bound | **Works** - Gen3 x8, P0, `nvidia-smi` reads it |
| Link survives with the driver stack loaded | **Open, but the trigger is found (2026-09-09 21:30).** It dies ~10s after the eGPU appears with the display engine **never initialised** (`modeset=0`, NVKMS sealed) - so it is not the display path. Every recorded death ends with `snd_hda_intel` probing the eGPU's **HDMI-audio function** (`01:00.1`) and the firmware call in flight is `DFP_SET_ELD_AUDIO_CAPS`; both survivors had no driver on that function and the internal 1650 has none. `on` now fences that function off by default (`--audio` to bind it). See [Findings §8](FINDINGS.md#8-the-ten-second-link-death--rtd3-was-not-the-cause) |

The reference machine is the most marginal configuration that exists: a DIY dock
with substituted connectors, on the oldest Flow model. If you have an official
dock, you are strictly closer to the happy path and several of these walls may
simply not be there for you.

## Is this for you?

**Probably yes if:** you have an ASUS ROG Flow or ROG Ally, an XG Mobile
(official or DIY), and a normal Linux distro (Arch, CachyOS, Fedora, Debian…).

**Probably no if:** you are on SteamOS or Bazzite. Use
[Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager)
instead - it handles the immutable root and Gaming Mode integration properly,
which this does not attempt.

## The one thing to read first

**[docs/RECOVERY.md](docs/RECOVERY.md)** - how to get your machine back.

`egpu_enable` is **persistent EC state.** It survives a reboot and a forced
power-off. If it commits and no eGPU enumerates, you have no discrete GPU at
all, and with the dock attached **the machine will not boot.** That is not a
brick, and the recovery takes five minutes, but only if you know it before you
need it.

Read that file before your first `xgm-egpu on`.

## Quick start

```sh
git clone https://github.com/ItzSkyeYT/xgm-egpu
cd xgm-egpu
sudo ./install.sh          # installs bin/xgm-egpu
sudo xgm-egpu install-rules  # udev PM pinning + modprobe shadow + initramfs rebuild
```

Then, with the dock connected and locked, and on AC power:

```sh
xgm-egpu detect            # safe, read-only - what it worked out about your machine
xgm-egpu preflight         # safe, read-only - is RTD3 disarmed? `on` refuses if not
xgm-egpu status            # safe, read-only
sudo xgm-egpu on
```

`status` tells you whether the EC has detected your dock (`egpu_connected=1`)
before you attempt anything that can wedge the machine. If it reads `0`, stop:
nothing else in this repo will help until the EC sees the board.

**The write takes a long time - up to a couple of minutes.** It drives a full
ACPI eject and PCI rescan synchronously. Slow is not stuck. A timeout does *not*
mean the write was rejected; the EC has usually already committed by then. See
[Findings §2](FINDINGS.md#2-a-timed-out-write-has-usually-already-succeeded).

## Commands

```
xgm-egpu status              attributes, bus state, modules, blockers
xgm-egpu detect              autodetected topology, and how it was derived
xgm-egpu preflight           is NVIDIA RTD3 disarmed in the LOADED driver? run this first
xgm-egpu gsp [status|off|on] disable NVIDIA GSP firmware (proprietary driver only)
xgm-egpu drm [status|nofbdev|nokms|safe|default]
                             set what the LOADED nvidia_drm does to the eGPU when it
                             appears (persisted via modprobe.d + initramfs; `on` verifies)
xgm-egpu logs [N|show|dir]   persistent per-run logs in /var/log/xgm-egpu (full
                             output of every on/off/bind/reload-driver, plus the
                             kernel log saved by the watch); survives reboots
xgm-egpu capture [arm|read]  armed automatically by `on`/`bind`; `read` after a
                             hang+reboot shows the kernel's last words from pstore
xgm-egpu bind <core|modeset|drm-nokms|drm-nofbdev|drm|audio|all>
                             bind one driver layer to an enumerated eGPU and
                             watch whether the link dies (bisection)
xgm-egpu watch [SECS]        sample power state every 0.5s after activation
xgm-egpu on                  release the internal dGPU, then activate
xgm-egpu off                 deactivate, restore the internal dGPU
xgm-egpu link [BDF]          PCIe link speed/width and error counters
xgm-egpu link-speed <1-4>    pin the root port's target generation and retrain
xgm-egpu ec                  decode the EC's XGM state block (connect/lock/AC)
xgm-egpu install-rules       persist runtime-PM pinning, disarm NVIDIA RTD3,
                             rebuild the initramfs if nvidia is baked in
```

Useful options:

```
--dry-run        everything except the sysfs write
--release LEVEL  minimal (default) | unload | remove
--link-gen N     pin PCIe generation 1-4 before switching
--no-reload      enumerate without binding NVIDIA - separates enumeration
                 faults from driver faults
--cap-power      lock clocks + min power limit before the display engine loads
                 (ruled out: card sat flat at 23 W and died anyway; kept for the record)
--no-kms         require the loaded nvidia_drm to have modeset=0 (`drm nokms` first):
                 render node only, the display engine is never touched. PRIME
                 render offload keeps working - see "Render-only mode" below
--mask-pciehp    stop pciehp turning a momentary Link Down into a teardown
--no-fbdev       require the loaded nvidia_drm to have fbdev=0 (`drm nofbdev` first).
                 Tested for real 2026-09-09 19:30: died identically. Ruled out
--audio          let snd_hda_intel bind the eGPU's HDMI-audio function. Off by default:
                 that codec is what every recorded death has in common
--modeset-safe   require the `drm safe` set (fbdev=0 + nvidia_modeset HDMI-FRL/VRR off)
--no-drm-poll    disable DRM's 10s connector poll (ruled out; kept for the record)
--timeout N      default 180s
--root-port BDF  override the autodetected PCIe root port
--internal-dgpu BDF
                 override the autodetected internal dGPU
```

**The display-layer flags only verify.** `nvidia_drm` attaches to a GPU the
moment it appears on the bus, with the parameters it was *loaded* with, and
`modprobe` silently ignores parameters for a module that is already resident.
So `on --no-fbdev` cannot load anything differently; it checks that the loaded
module already is `fbdev=0` and refuses otherwise. Set the layer once with
`sudo xgm-egpu drm nofbdev` (or `nokms`, `safe`), apply it with
`sudo xgm-egpu reload-driver --force-kill` or a reboot, confirm with
`xgm-egpu drm status`, then activate. Three earlier "ruled out" results in the
findings were this trap - [Findings §8](FINDINGS.md#8-the-ten-second-link-death--rtd3-was-not-the-cause).

## Render-only mode (no monitor on the eGPU)

If you do not need to drive a monitor from the eGPU's own ports - you just
want its compute and render power for games and apps on the laptop screen -
`drm nokms` (`nvidia_drm modeset=0`) is the safest configuration: the eGPU
gets a DRM **render node only**, and the display-engine bring-up that every
death so far happened inside is never run.

What still works with `modeset=0`, checked on this driver (580) by tracing the
ioctls a PRIME client makes and emulating the kernel's `modeset=0` behaviour
for it (the exact set of gated ioctls, `GET_DEV_INFO` reporting no NVKMS
allocation): CUDA / OpenCL / headless Vulkan, and **PRIME render offload** -
the NVIDIA userspace falls back from `GEM_IMPORT_NVKMS_MEMORY` (modeset-gated)
to `GEM_IMPORT_USERSPACE_MEMORY` (not gated) for the buffers it shares with the
iGPU. Xwayland/X11 clients (which is what Proton games are) render and present
normally; native-Wayland clients present through a slower copy path.

```sh
prime-run vkcube            # or: __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>
prime-run glxinfo -B        # must name the eGPU
# Steam launch options:      prime-run %command%
```

On a Flow the internal dGPU is ejected when the XG Mobile is active, so the
eGPU is the only NVIDIA GPU and `prime-run` needs no device selection.

The catch, measured on the internal dGPU: with `modeset=0` loaded, **kwin
brings the display engine up anyway 1.5 s after a GPU appears** (its Vulkan
probe of the new device), and every PRIME client does so once at start -
`NVKMS_IOCTL_ALLOC_DEVICE` has no privilege check. So `on --no-kms` **seals
the door** first: it bind-mounts `/dev/null` over `/dev/nvidia-modeset`.
Clients still open it, every display-engine ioctl fails, and they carry on
(vkcube, vulkaninfo, glxgears all tested; the allocation count stays flat).
`off` unseals. Making the node unopenable instead is not an option - the
Vulkan driver segfaults on that. `--no-seal` skips the seal on purpose.

`--release minimal` is the default **and on the reference machine it is the only
level that has ever survived.** More teardown makes it fail harder and faster.
That is counterintuitive and it is the single most important finding in this
repo - [Findings §6](FINDINGS.md#6-less-teardown-not-more).

## Hardware

| Host | Dock | Result |
|---|---|---|
| ROG Flow X13 GV301QH | DIY osy Lite v0.6.1, RTX 3060, ALC04-S40EIA-00 connectors | Unbound: Gen3 x8 stable, 0 AER. Bound: dies at exactly 10s ([§8](FINDINGS.md#8-the-ten-second-link-death--rtd3-was-not-the-cause)) |
| ROG Ally + CachyOS | DIY osy, RTX 3080 | Testing in progress |

If you run this on anything, please [open an
issue](../../issues) with your `xgm-egpu status` output - see
[CONTRIBUTING.md](CONTRIBUTING.md). The tested-hardware table is the most
valuable thing this repo can accumulate.

## Other machines

**Nothing to configure.** Topology is autodetected from sysfs at startup - the
internal dGPU, its device ID, and the PCIe root port the XG Mobile shares lanes
with. Check what it worked out:

```sh
xgm-egpu detect
```

Hosts with **no internal dGPU** (ROG Ally) are supported and are the easier case:
nothing shares the XGM's lanes, so activation triggers no eject, and the entire
release path - the hardest part of this problem - is a no-op. Detection finds the
root port from the empty hotplug slot instead.

Detection only refuses to guess when a host has several empty hotplug slots and
no internal dGPU to disambiguate them. It says so, and you set one value:

```sh
# /etc/xgm-egpu.conf
ROOT_PORT=0000:00:01.1
```

`--root-port` and `--internal-dgpu` do the same thing for one run.

If detection gets your machine wrong, that is a bug worth reporting - paste
`xgm-egpu detect` into an issue. [docs/PORTING.md](docs/PORTING.md) explains how
the detection works and how to derive the values by hand.

## Documentation

- **[docs/RECOVERY.md](docs/RECOVERY.md)** - unbootable machine, wedged terminal, stuck EC state
- **[FINDINGS.md](FINDINGS.md)** - the reverse-engineering: AML decode, teardown ordering, power management, and the dead ends so you don't repeat them
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - symptom → cause → fix
- **[docs/PORTING.md](docs/PORTING.md)** - adapting to another Flow or an Ally

## Credits

- **[osy/XG_Mobile_Station](https://github.com/osy/XG_Mobile_Station)** - the DIY dock, and `Docs/ACPI_Annotated.asl` + `Docs/Software.md`, which are the single most useful references for any of this. Most of [FINDINGS.md](FINDINGS.md) is applied osy.
- **[stensmir/xg-mobile-linux](https://github.com/stensmir/xg-mobile-linux)** - first to show the sysfs write is all you need on SteamOS.
- **[Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager)** - the mature SteamOS/Bazzite implementation.
- **Luke Jones and the [asus-linux](https://asus-linux.org/) project** - `asus-wmi` and `asus-armoury`, which are what make any of this possible from userspace.

## Maintenance

**Unmaintained by default.** This is research published in case it helps, by
someone with one machine and limited time. Issues are welcome and will be read,
but do not expect timely fixes. Forks are encouraged.

## Licence

MIT - see [LICENSE](LICENSE).
