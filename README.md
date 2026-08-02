# xgm-egpu

Activating an ASUS XG Mobile eGPU on an ordinary Linux distribution — including
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
| Link trains above PCIe Gen1 | **Fails on the reference machine** — see [Findings](FINDINGS.md#pcie-link-speed) |
| GPU initialises and renders | **Open** — `Xid 154 GPU Reset Required` |

The reference machine is the most marginal configuration that exists: a DIY dock
with substituted connectors, on the oldest Flow model. If you have an official
dock, you are strictly closer to the happy path and several of these walls may
simply not be there for you.

## Is this for you?

**Probably yes if:** you have an ASUS ROG Flow or ROG Ally, an XG Mobile
(official or DIY), and a normal Linux distro (Arch, CachyOS, Fedora, Debian…).

**Probably no if:** you are on SteamOS or Bazzite. Use
[Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager)
instead — it handles the immutable root and Gaming Mode integration properly,
which this does not attempt.

## The one thing to read first

**[docs/RECOVERY.md](docs/RECOVERY.md)** — how to get your machine back.

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
sudo ./install.sh          # installs bin/xgm-egpu, udev rule, modprobe.d conf
```

Then, with the dock connected and locked, and on AC power:

```sh
xgm-egpu status            # safe, read-only — always start here
sudo xgm-egpu on
```

`status` tells you whether the EC has detected your dock (`egpu_connected=1`)
before you attempt anything that can wedge the machine. If it reads `0`, stop:
nothing else in this repo will help until the EC sees the board.

**The write takes a long time — up to a couple of minutes.** It drives a full
ACPI eject and PCI rescan synchronously. Slow is not stuck. A timeout does *not*
mean the write was rejected; the EC has usually already committed by then. See
[Findings §2](FINDINGS.md#2-a-timed-out-write-has-usually-already-succeeded).

## Commands

```
xgm-egpu status              attributes, bus state, modules, blockers
xgm-egpu on                  release the internal dGPU, then activate
xgm-egpu off                 deactivate, restore the internal dGPU
xgm-egpu link [BDF]          PCIe link speed/width and error counters
xgm-egpu link-speed <1-4>    pin the root port's target generation and retrain
xgm-egpu ec                  decode the EC's XGM state block (connect/lock/AC)
xgm-egpu install-rules       persist the runtime-PM pinning
```

Useful options:

```
--dry-run        everything except the sysfs write
--release LEVEL  minimal (default) | unload | remove
--link-gen N     pin PCIe generation 1-4 before switching
--no-reload      enumerate without binding NVIDIA — separates enumeration
                 faults from driver faults
--timeout N      default 180s
```

`--release minimal` is the default **and on the reference machine it is the only
level that has ever survived.** More teardown makes it fail harder and faster.
That is counterintuitive and it is the single most important finding in this
repo — [Findings §6](FINDINGS.md#6-less-teardown-not-more).

## Hardware

| Host | Dock | Result |
|---|---|---|
| ROG Flow X13 GV301QH | DIY osy Lite v0.6.1, RTX 3060, ALC04-S40EIA-00 connectors | Enumerates, binds, Gen1 only, `Xid 154` |
| ROG Ally + CachyOS | DIY osy, RTX 3080 | Testing in progress |

If you run this on anything, please [open an
issue](../../issues) with your `xgm-egpu status` output — see
[CONTRIBUTING.md](CONTRIBUTING.md). The tested-hardware table is the most
valuable thing this repo can accumulate.

## Porting to another machine

The script currently hardcodes three values for the reference Flow X13. On a
ROG Ally — which has **no internal dGPU** — the entire hard half of this problem
does not exist, and only one of those three values matters.

See [docs/PORTING.md](docs/PORTING.md).

## Documentation

- **[docs/RECOVERY.md](docs/RECOVERY.md)** — unbootable machine, wedged terminal, stuck EC state
- **[FINDINGS.md](FINDINGS.md)** — the reverse-engineering: AML decode, teardown ordering, power management, and the dead ends so you don't repeat them
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — symptom → cause → fix
- **[docs/PORTING.md](docs/PORTING.md)** — adapting to another Flow or an Ally

## Credits

- **[osy/XG_Mobile_Station](https://github.com/osy/XG_Mobile_Station)** — the DIY dock, and `Docs/ACPI_Annotated.asl` + `Docs/Software.md`, which are the single most useful references for any of this. Most of [FINDINGS.md](FINDINGS.md) is applied osy.
- **[stensmir/xg-mobile-linux](https://github.com/stensmir/xg-mobile-linux)** — first to show the sysfs write is all you need on SteamOS.
- **[Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager)** — the mature SteamOS/Bazzite implementation.
- **Luke Jones and the [asus-linux](https://asus-linux.org/) project** — `asus-wmi` and `asus-armoury`, which are what make any of this possible from userspace.

## Maintenance

**Unmaintained by default.** This is research published in case it helps, by
someone with one machine and limited time. Issues are welcome and will be read,
but do not expect timely fixes. Forks are encouraged.

## Licence

MIT — see [LICENSE](LICENSE).
