# Troubleshooting

Symptom → cause → fix. For anything that has left the machine unusable, go
straight to [RECOVERY.md](RECOVERY.md).

Always start with the read-only command:

```sh
xgm-egpu status
```

---

## The card enumerates, binds, then dies about 10 s later (Xid 79, link 8.0 → 5.0 GT/s)

This is the one. The NVIDIA driver retrains the PCIe link when the GPU leaves
P0 after init, and a marginal link does not survive a retrain at Gen3. Zero
AER errors, flat power, a clean Link Down. `go` applies the fix: `pcie gen3`
so the driver may keep Gen3, and `--freeze-link` so the GPU stays in P0 with
the autonomous-speed bits disabled on both ends. If it still dies **with** a
`LINK SPEED CHANGED` line in the watch, the firmware ignored the freeze; cap
the link instead: `sudo xgm-egpu on --no-kms --link-gen 2 --force-kill` (no
equalization at Gen2, 4 GB/s). [FINDINGS §8](../FINDINGS.md#8-the-ten-second-link-death--rtd3-was-not-the-cause).

---

## `egpu_connected = 0`

**The EC does not see your dock.** Nothing else in this repo will help until
this reads `1`. Activation is refused with `-ENOENT` by design.

Check, in order:

1. **Is the connector fully seated and locked?** The AML checks a *lock* bit
   separately from the connect bit and refuses to proceed without it.
2. **Is the machine on AC?** The AML fails if AC is lost. `xgm-egpu status`
   reports this.
3. **Is the dock powered?** DIY docks have their own ATX supply.
4. **Did you connect while the system was running?** On Windows the XGM cable
   must be attached with the OS already up. Cold-boot attachment is not the
   supported path.

Watch for the EC event when you plug in:

```sh
sudo dmesg -w | grep -i 'unknown key code'
```

`0xb9` on connect means the EC saw it. No event at all means the detect line is
not reaching the EC — a hardware problem, not a software one.

---

## `refusing to proceed — close these first`

Both `on` and `off` refuse to write while anything holds `/dev/nvidia*`, because
writing then would park your shell in unkillable `D` state. The message lists
the processes.

Close them, or override:

```sh
sudo xgm-egpu on  --force-kill      # SIGTERM, wait 3s, SIGKILL
sudo xgm-egpu off --force-kill
```

Note this applies to `off` as well, which matters because `off` is the recovery
path — see [RECOVERY.md](RECOVERY.md).

Common holders: `nvidia-powerd` and `nvidia-persistenced` (stopped automatically),
then browsers, Electron apps, VMs, and compositors.

`lsof` is used to find them when present; otherwise the script walks `/proc`
itself, so a missing `lsof` no longer causes the check to silently pass.

**If the list names half your system** (systemd, NetworkManager, your shell,
`lsof` itself), you have a version from before 2026-10-28: there, `lsof` could
report every process on a machine with no NVIDIA device on the bus, and
`--force-kill` would have signalled all of them. Update first. Now only
processes with an NVIDIA node actually open are listed, and `--force-kill`
checks each one again in `/proc` and never signals PID 1.

---

## Write hangs, process unkillable, `Ctrl-C` does nothing

See [RECOVERY.md § terminal wedged](RECOVERY.md#symptom-terminal-wedged-process-unkillable).

Short version: something holds `/dev/nvidia*` open. Usually `nvidia-powerd`.

```sh
sudo fuser -v /dev/nvidia*
sudo systemctl stop nvidia-powerd nvidia-persistenced
```

Use `xgm-egpu on` instead of writing sysfs by hand — it does this for you and
never blocks your shell indefinitely.

---

## The write "timed out"

**It probably worked.** See [Findings §2](../FINDINGS.md#2-a-timed-out-write-has-usually-already-succeeded).

The EC commits *before* the blocking part. Reading `current_value` back as `0`
tells you nothing. Do not retry — a second write queues behind the first and
makes things worse.

Wait. Then check:

```sh
lspci -nn | grep -i 10de
sudo dmesg | tail -40
```

---

## Machine dies instantly, nothing in the log

**You tore down too much before the write.** This is the counterintuitive one —
see [Findings §6](../FINDINGS.md#6-less-teardown-not-more).

Do **not** unload the NVIDIA modules, unbind the driver, or remove the PCI
device beforehand. The firmware polls for the OS to complete a real eject; if
you have already removed everything, there is no eject to complete.

```sh
sudo xgm-egpu on --release minimal     # the default, and the only one that survives
```

If you were experimenting with `--release unload` or `--release remove`, stop.
They exist only to reproduce the failing approaches for comparison.

---

## GPU appears, then `Xid 79 — GPU has fallen off the bus`

If it happens ~10 s after the driver binds, see the first section: it is the
link retrain, not power management. If it happens at idle with `install-rules`
not applied, it is runtime power management. See [Findings §7](../FINDINGS.md#7-runtime-power-management-drops-the-link).

```sh
sudo xgm-egpu install-rules
```

Verify both port and endpoint are pinned:

```sh
cat /sys/bus/pci/devices/0000:00:01.1/power/control     # want: on
cat /sys/bus/pci/devices/<egpu-bdf>/power/control       # want: on
```

`pcie_port_pm=off` alone is **not** sufficient — it does not cover the endpoint.

---

## GPU appears and binds, but will not initialise

```
NVRM: Xid 154, GPU Reset Required
nvidia-modeset: Error while waiting for GPU progress
```

**Unsolved.** Two things to try, cheapest first:

1. **Power-cycle the dock at the mains.** No host reboot removes power from a
   card fed by the dock's own supply. A GPU latched into "reset required" stays
   latched across host reboots. Off, 30 seconds, on.
2. **Disable Resizable BAR** in the BIOS ("Re-Size BAR Support" / "Above 4G
   Decoding").

If either works, please open an issue.

---

## Link is stuck at Gen1, or dies at higher speeds

Resolved: the link is fine at any steady speed and dies when *retrained* at
Gen3. See the first section. What follows is the earlier, superseded advice.

```sh
xgm-egpu link                    # current speed, width, error counters
sudo xgm-egpu link-speed 1       # pin Gen1 and retrain
```

On the reference machine Gen1 is stable and Gen2/Gen3 cannot complete training.
`--link-gen 1` is the working mitigation.

Do **not** set ASPM to `performance` — it sounds right and made things strictly
worse.

If you have an official dock, your link speed is the most useful data point
anyone can contribute to this repo.

---

## Boot hangs with the dock attached

See [RECOVERY.md](RECOVERY.md#symptom-the-machine-will-not-boot-with-the-dock-attached).

Force off → **unplug the dock** → boot → `sudo xgm-egpu off` → reboot.

---

## `sudo xgm-egpu` says "command not found"

`~/.local/bin` is on your interactive `PATH` but not on sudo's `secure_path`.

```sh
sudo ln -sf "$(command -v xgm-egpu)" /usr/local/bin/xgm-egpu
```

`install.sh` does this for you.

---

## `no external NVIDIA device appeared after 20s`

The write went through and the firmware switched the lanes, but no GPU showed
up on the bus. The tool now says which case you are in:

- **`pending_reboot` went from 0 to 1 on that write** (the kernel also logs
  *"Success changing the eGPU status, a reboot is strongly advised"*): the
  firmware powered the dock, read the GPU's ID over the link and got nothing
  back. On the osy boards the cable LED is red at this point. This is a
  hardware fault on the dock side, and rebooting does not fix it. Check, one change at a
  time: the GPU seated in the slot, its 8-pin, the dock's PSU on; the XGM cable
  fully in at both ends (40-pin connectors home, bar locked, shield screw
  tight); then another cable, another board, the GPU in a desktop. Fans
  spinning only proves the card has power. If Windows fails the same way on the
  same machine, that settles it. Seen on a 2023 Flow X13 with an osy board
  (2026-10-27): another cable and the 0.6 board fixed it.
- **Otherwise:** look at `dmesg | grep -iE 'pci|asus|egpu|pciehp' | tail -40`
  for a link that came up and went down again, and see the link sections below.

Either way `egpu_enable` is now 1 and stays 1 across reboots: unplug the XGM
cable and run `sudo xgm-egpu off` to get the internal dGPU back
([RECOVERY.md](RECOVERY.md)).

---

## `ROOT_PORT` was not detected, or you had to set it by hand

The port is normally found as the parent bridge of the internal dGPU, which only
works while that GPU is visible. Two things hide it:

- **Eco mode** (`dgpu_disable=1`, from G-Helper or Armoury Crate). Switch to
  Standard or Optimized, then run `xgm-egpu detect` again.
- **`egpu_enable` still 1** from an earlier attempt, here or in Windows. Unplug
  the XGM cable, `sudo xgm-egpu off`, then `detect`.

Since 2026-10-28 detection also reads the port from ACPI in both cases: the
bridge whose ACPI node holds the dGPU's `PEGP` (`0000:00:01.1` on the 2021 and
2023 Flow X13). `xgm-egpu detect` prints where its answer came from, and warns
if a hand-set `ROOT_PORT` disagrees with ACPI. To check by hand, with the
internal dGPU visible:

```sh
lspci -D | grep -i nvidia     # e.g. 0000:01:00.0
basename "$(dirname "$(readlink -f /sys/bus/pci/devices/0000:01:00.0)")"   # e.g. 0000:00:01.1
```

---

## A monitor on the eGPU stays black

Plain `go` is render-only and keeps the card's display engine off, so the
monitor is detected but never lights up. Use `go --display`, then
`desktop pin --outputs`, then log out and in: see "A monitor on the eGPU's own
ports" in the [README](../README.md). If it is still black, send
`xgm-egpu desktop status` and `ls /sys/class/drm` taken while the eGPU is on.

---

## On Windows (for people who arrive from the osy Discord)

This repo is about Linux, but the same docks come up here. What we have seen:

- **XGMDriver is all you need.** XGMActivator is outdated; osy replaced it with
  XGMDriver in release 0.5. Use the latest installer and pick the right vendor:
  installers before 0.5.1 swapped the AMD and NVIDIA choices.
- **Lite board on a ROG Ally:** in one case (2026-10-21) the lanes only switched once
  the board's USB-C link was plugged in and the XGM cable replugged with Windows
  running. The Lite cannot tell which way round that USB-C plug is, so if the
  cable LED stays white after activating, flip it over.
- **The LED:** white = cable connected and host on, red = PCIe lanes switched.
- **Error 43:** the egpu.io *nvidia-error43-fixer* (1.1.3, Feb 2021, still the
  latest) lives in [its forum thread](https://egpu.io/forums/expresscard-mpcie-m-2-adapters/script-nvidia-error43-fixer/),
  behind a free login; the short link in osy's README is dead. Run it as
  administrator after the NVIDIA driver, and again after every driver update.
  Many setups never need it.
- **Games on the internal GPU:** Settings → System → Display → Graphics, set the
  game (or the default) to High performance; or plug the monitor into the
  eGPU.

---

## Nothing above matches

Collect this and open an issue:

```sh
xgm-egpu status
uname -r
lspci -nn
sudo dmesg | grep -iE 'asus|nvidia|pcieport|nvrm|xid|acpi' | tail -60
cat /sys/class/dmi/id/product_name
```

Note that `kernel.dmesg_restrict=1` on many distros means every diagnostic from
the driver is invisible without `sudo`. A silent failure is usually a readable
one with the right privileges.
