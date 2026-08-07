# Recovery

**Read this before your first activation attempt, not after.**

Nothing here bricks a machine. But two of these states look like a dead laptop
if you meet them without warning, and one of them cannot be fixed by rebooting
— which is the first thing everybody tries.

---

## The fact that makes recovery non-obvious

**`egpu_enable` is persistent EC state.** It lives in the embedded controller,
not in Linux. It survives:

- a reboot
- a full shutdown
- holding the power button
- pulling the battery, if you can

Rebooting does not reset it. If you learn one thing from this repo, learn this
one, because every instinct says otherwise.

---

## Symptom: the machine will not boot with the dock attached

**What you see.** Power on with the dock connected and it hangs before or during
boot. Without the dock it boots fine. Possibly a BIOS warning about the eGPU.

**What happened.** `egpu_enable=1` committed to the EC, but no eGPU actually
enumerated. The internal dGPU is switched off with nothing replacing it, and at
power-on the firmware tries to hand the PCIe lanes to the XG Mobile that isn't
answering.

**Recovery — verified working:**

1. Force power off (hold the power button).
2. **Disconnect the eGPU.** This step is the one people skip.
3. Boot. It boots normally without the dock.
4. Clear the EC state:
   ```sh
   sudo xgm-egpu off
   ```
   **Expect this to block for a long time — well past 25 seconds.** Let it run.
   It is doing a real ACPI transition. See [Findings §3](../FINDINGS.md#3-blocking-is-structural-and-slow-is-not-stuck).

   **If it refuses instead of blocking**, with `refusing to proceed — close these
   first`, something still holds `/dev/nvidia*`. That guard is protecting you
   from a D-state wedge, but it also stands between you and your recovery. Close
   whatever it lists, or override it:

   ```sh
   sudo xgm-egpu off --force-kill
   ```

   `--force-kill` sends SIGTERM to the listed processes, waits 3 s, then SIGKILL.
   In the unbootable-machine case there is usually nothing holding the GPU
   anyway — `egpu_enable=1` means the internal card is switched off, so no
   driver is bound to anything.
5. Reboot to clear `pending_reboot`.

Your internal dGPU comes back, bound to `nvidia`.

**Why `off` works with the dock unplugged.** The kernel's connected-check is
enable-only:

```c
if (enable) {
        /* Ensure the eGPU is connected before attempting to activate it. */
        if (!result) { pr_warn("Cannot activate eGPU while undetected\n"); return -ENOENT; }
}
```

So you can always write `0`, dock or no dock. Disabling is also a device *add*
rather than an eject, so there is no `nv_pci_remove()` to stall on. This is the
reliable escape hatch from every bad state in this document.

---

## Symptom: terminal wedged, process unkillable

**What you see.** Your `echo 1 > .../egpu_enable` never returns. `Ctrl-C` does
nothing. `kill -9` does nothing. The rest of the machine works fine.

**Check it:**

```sh
ps -eo pid,stat,etimes,comm | awk '$2 ~ /D/'
```

State `D` is uninterruptible sleep. It cannot be killed, by design.

**What happened.** Activation makes ACPI eject the *internal* dGPU. NVIDIA's
`nv_pci_remove()` then polls in `os_delay()` until the internal GPU's usage
count reaches zero. Something still holds it open, so the eject never completes,
the ACPI hotplug mutex is held, and your writer parks in `D` behind it.

**Find the holder:**

```sh
sudo fuser -v /dev/nvidia*
```

The usual culprit is **`nvidia-powerd`** — root-owned, holds ~15 fds, restarts
on every boot, and survives quitting every GUI application. It is very easy to
miss because closing your desktop apps appears to change nothing.

Anything with GPU acceleration can also do it. On the reference machine an
Electron application's GPU helper process held `/dev/nvidiactl` and stalled a
switch this way.

**Release it:**

```sh
sudo systemctl stop nvidia-powerd nvidia-persistenced
```

On one occasion this released an eject that had been stuck for **856 seconds**,
and it completed instantly.

**Verify nothing is left** — refcount arithmetic:

```
/sys/module/nvidia/refcnt  ==  (open fds)  +  (3 dependent modules)
```

If `refcnt` exceeds that, something still holds the GPU.

**If the wedge does not clear:** reboot. `systemctl reboot` may itself stall on
the unkillable task; escalate to `systemctl reboot -ff`. The EC state persists
across that reboot, so afterwards go back to the unbootable-machine procedure
above and run `xgm-egpu off`.

**Prevention:** use `xgm-egpu on` rather than writing sysfs by hand. It stops
the fd holders first, unbinds in *its own process context* so a stall is
survivable, and never lets the write block your shell indefinitely.

---

## Symptom: GPU enumerates, then vanishes seconds later

**What you see.**

```
pcieport 0000:00:01.1: pciehp: Slot(0): Link Down
pcieport 0000:00:01.1: pciehp: Slot(0): Card not present
NVRM: Xid 79, GPU has fallen off the bus.
```

Typically 10–40 seconds after a successful activation.

**What happened.** Runtime power management suspended the link. The root port
runtime-suspends ~100 ms after idle, drops to D3cold, and the link never comes
back.

**Fix:**

```sh
sudo xgm-egpu install-rules
```

This pins `power/control=on` for the root port *and* the endpoint, and sets
`NVreg_DynamicPowerManagement=0`.

**Both halves are required.** The port and the endpoint must be pinned
separately — `pcie_port_pm=off` on the kernel command line does **not** cover
the card, and the NVIDIA driver has its own independent route into D3cold. See
[Findings §7](../FINDINGS.md#7-runtime-power-management-drops-the-link).

The rules are harmless when the eGPU is not connected.

---

## Symptom: booting with the dock attached never reaches a login

If the GPU enumerates but fails to initialise, `nvidia-modeset` spins on the
dead device and you never get a usable session.

**Boot without the dock** to get a working desktop. Attach and run `xgm-egpu on`
from there. This is the normal working pattern on the reference machine, not a
workaround for a broken install.

---

## Symptom: `Xid 154 — GPU Reset Required`

The GPU enumerates cleanly, the driver binds, and then it will not initialise —
`nvidia-modeset: Error while waiting for GPU progress`.

**This is unsolved on the reference machine.** Two things to try, cheapest first:

1. **Power-cycle the dock itself, at the mains.** The dock has its own ATX
   supply, so *no host reboot has ever removed power from the card.* A GPU
   latched into "reset required" by earlier `Xid 79`s can stay latched
   indefinitely across host reboots. Switch the supply off, wait 30 seconds,
   back on. Costs one reboot and changes no configuration.

2. **Disable Resizable BAR in the BIOS** ("Re-Size BAR Support" / "Above 4G
   Decoding"). At cold boot the firmware assigns a 16 GB BAR aperture, while the
   hotplug path assigns 256 MB. ReBAR over an eGPU link is a known cause of
   "enumerates cleanly, will not initialise".

If either works for you, please open an issue — it closes the last open question
in this repo.

---

## Escape hatch summary

Whatever state you are in, this sequence gets you back to a working machine with
your internal GPU:

```sh
# 1. force power off
# 2. unplug the dock
# 3. boot
sudo xgm-egpu off       # be patient, it blocks
sudo reboot
```

If `off` refuses because something holds `/dev/nvidia*`, add `--force-kill`.

If `xgm-egpu` itself is unavailable, the same thing by hand:

```sh
echo 0 | sudo tee /sys/class/firmware-attributes/asus-armoury/attributes/egpu_enable/current_value
```
