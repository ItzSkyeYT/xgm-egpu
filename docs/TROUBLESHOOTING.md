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
