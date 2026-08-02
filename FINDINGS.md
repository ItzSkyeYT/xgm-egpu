# Findings

Reverse-engineering notes for XG Mobile activation on Linux. Derived on a ROG
Flow X13 GV301QH with a DIY [osy](https://github.com/osy/XG_Mobile_Station) Lite
v0.6.1 dock and an RTX 3060, between 2026-07-28 and 2026-07-31.

Much of this is applied osy: `Docs/ACPI_Annotated.asl` and `Docs/Software.md` in
that repo are the primary sources and are worth reading before this file.

The negative results at the end are as valuable as the positive ones. Each cost
hours.

---

## 0. The interface already exists

There is no reverse engineering required to *activate* an XG Mobile on Linux. No
`acpi_call`, no DSDT patching, no extracting ACPI methods from Windows drivers.

`asus-armoury` exposes it directly:

```
/sys/class/firmware-attributes/asus-armoury/attributes/egpu_enable/current_value
/sys/class/firmware-attributes/asus-armoury/attributes/egpu_connected/current_value
/sys/class/firmware-attributes/asus-armoury/attributes/dgpu_disable/current_value
```

Legacy aliases exist under `/sys/devices/platform/asus-nb-wmi/` when
`CONFIG_ASUS_WMI_DEPRECATED_ATTRS=y`.

DEVIDs, from `include/linux/platform_data/x86/asus-wmi.h`:

| Constant | Value |
|---|---|
| `ASUS_WMI_DEVID_EGPU_CONNECTED` | `0x00090018` |
| `ASUS_WMI_DEVID_EGPU` | `0x00090019` |
| `ASUS_WMI_DEVID_DGPU` | `0x00090020` |

`egpu_enable` accepts `0..3`, mapping to `{0: 0x0, 1: 0x1, 2: 0x101, 3: 0x201}`.
Values 2 and 3 are undocumented in the kernel source and untested here. Use `1`.

The kernel calls `armoury_pci_rescan()` itself after a successful write, so
**you do not need `echo 1 > /sys/bus/pci/rescan`** and you do not need a udev
rule for enumeration. (Older SteamOS-targeted projects do this manually because
they predate that.)

### A DIY dock is detected exactly like an official one

`egpu_connected = 1` on a DIY osy board means the EC has genuinely detected it.
The EC also emits the full XG Mobile event sequence, which `asus-wmi` surfaces
as unmapped keycodes:

| Code | Meaning (per osy) |
|---|---|
| `0xB9` | Connect Change — connector mated or unmated |
| `0xBA` | Switch-Lock Change — lock asserted/deasserted |
| `0xBB` | External Power Loss |
| `0xBE` | Readiness to disable eGPU (sent before `SUMA`) |
| `0xC2` | Restart required |

Seeing `asus_wmi: Unknown key code 0xb9` in `dmesg` when you plug in is not an
error. It is proof the proprietary handshake is happening.

---

## 1. `egpu_enable` is persistent EC state

It survives a reboot, a shutdown, and a forced power-off. It is not Linux state.

This is the single most important operational fact in this document, because
every debugging instinct says "reboot and try again", and rebooting into a
committed `egpu_enable=1` with no working eGPU produces a machine that will not
boot. See [RECOVERY.md](docs/RECOVERY.md).

---

## 2. A timed-out write has usually already succeeded

From `egpu_enable_current_value_store()` in `drivers/platform/x86/asus-armoury.c`,
the order of operations is:

```c
armoury_set_devstate(..., ASUS_WMI_DEVID_EGPU)   /* commits to the EC HERE */
... switch (result) ...
armoury_pci_rescan()                             /* then blocks HERE */
```

`armoury_pci_rescan()` wants `pci_rescan_remove_lock`. The `kacpi_hotplug`
worker is already holding it — performing the eject that the WMI call on the
previous line just triggered. So the writing process blocks for the entire
duration of the eject, **after the EC has already committed.**

Consequences:

- A write that times out has very likely still taken effect.
- Reading `current_value` back as `0` afterwards **means nothing.**
- **Never interpret a timeout as "the write was rejected."**

Treating a 25-second timeout as a rejection sent this investigation chasing a
hardware fault that did not exist.

---

## 3. Blocking is structural, and slow is not stuck

The lock ordering above makes some blocking unavoidable. This is not a kernel
bug and it is not your hardware.

Observed: a write that "timed out" at 25 s completed successfully on its own a
short while later, with both the EC change and the PCI rescan applied. A
successful activation took 28 seconds end to end. A stalled eject once took
**856 seconds** and then completed.

Give it minutes, not seconds. `xgm-egpu` waits 180 s by default and prints a
reassurance at 20 s so you do not panic and power-cycle mid-transition.

---

## 4. What actually stalls the eject

Activating the eGPU makes ACPI eject the **internal** dGPU — the XG Mobile port
shares its PCIe lanes, which is *why* the eject happens. NVIDIA's
`nv_pci_remove()` then polls in `os_delay()` until the internal GPU's usage
count reaches zero.

The stack trace of a stall looks like this:

```
kworker/u64:4  [state: S]   Workqueue: kacpi_hotplug
  acpi_device_hotplug -> acpiphp_disable_and_eject_slot
   -> pci_device_remove -> nv_pci_remove -> os_delay -> schedule_timeout
INFO: task tee:NNNN is blocked on a mutex likely owned by task kworker/u64:4:269
```

Note the worker is in state `S`, not `D`. It is not deadlocked — it is polling,
and it resumes the instant the last reference drops.

**The usual holder is `nvidia-powerd`**: root-owned, ~15 fds on `/dev/nvidia0`
and `/dev/nvidiactl`, restarts on every boot. Because it is a system service it
survives quitting every GUI application, which makes it very easy to miss.

Any GPU-accelerated application can do the same. An Electron app's GPU helper
process holding `/dev/nvidiactl` stalled a switch during this investigation.

**On a host with no internal dGPU — the ROG Ally — none of this exists.** There
is nothing to eject and nothing to stall. This is the single biggest difference
between Flow and Ally, and it is why SteamOS-targeted projects never had to
solve it.

---

## 5. The `egpu_connected` guard is enable-only

```c
if (enable) {
        /* Ensure the eGPU is connected before attempting to activate it. */
        if (!result) { pr_warn("Cannot activate eGPU while undetected\n"); return -ENOENT; }
}
```

You can always write `0` with the dock unplugged. Disabling is a device *add*,
not an eject, so there is no `nv_pci_remove()` to stall on. This is the reliable
escape hatch from any bad state.

WMI results: `0x01` = success. `0x02` = success but a reboot is advised; the
kernel calls `asus_set_reboot_and_signal_event()` and `pending_reboot` becomes 1.

---

## 6. LESS teardown, not more

**This is the most useful finding here, and it is the opposite of what everyone
tries first.**

Four activation attempts, ordered by how much was stripped out beforehand:

| # | State before the write | Outcome |
|---|---|---|
| 1 | nvidia loaded **and bound**, `nvidia-powerd` holding 15 fds | stalled 856 s, then **survived and recovered** |
| 2 | modules unloaded, driver unbound | hard machine death |
| 3 | + `nvidia-powerd` masked | hard death, fastest yet |
| 4 | + PCI device removed from the tree | hard death |

The only attempt that did not kill the machine is the one where **Linux
performed a genuine eject.** Every "cleanup" made it worse.

The death is total and logless:

```
13:21:55 [drm] [nvidia-drm] [GPU ID 0x00000100] Removing device
13:21:56 nvidia-modeset: Unloading
13:21:56 asus_wmi: Unknown key code 0xbe
13:21:56 asus_wmi: Unknown key code 0xc2
         <end of log — nothing further was ever written>
```

No oops, no panic, no ACPI error, no `BUG`. A kernel crash writes *something*.
This writes nothing, which is what losing the bus or a power rail looks like.

### Why — from the AML

`WMNB` / `DEVS 0x00090019`, the exact call the kernel makes, runs:

1. Read 4 bytes at EC offset `0x1C` — connected bit, **lock** bit, AC-loss bit.
2. **Fail if AC lost or the lock is not engaged.**
3. `SUMA(0x01)` — disable the competing GPU: send eject notify `0x03` to
   `PCI0.GPP0.PEGP`, **then poll via `WAT1()` waiting for the OS to actually
   complete the eject.**
4. Sleep 1000 ms.
5. Write GPU type to EC (`0x0A` off / `0x0B` on), set `GPUM`/`GPUV`.
6. Configure the PCIe bridge via `M018()`.
7. `WEBC(0x1C, 0x01, EGIF)`.
8. **`FGON()` — power the dock hardware. Sleep 2000 ms.**
9. `SHGM(0x02)` probes the device; returns `0x02` if VID/PID reads `0xFFFFFFFF`.

**Step 3 is the trap.** Remove the device and driver beforehand and `acpiphp`
has nothing to eject. No state transition occurs. The firmware polls for
something that will never arrive, gives up, and proceeds to `FGON()` with the
platform not where it believes it is.

This also explains Windows: the NVIDIA driver is loaded there and PnP performs
the removal, so the firmware always gets the response it polls for.

The whole eject, the delays, the dock power-on and the probe all happen *inside*
the single sysfs write. That is why the write blocks for so long.

**Practical rule: `--release minimal`.** Stop the fd holders so the eject can
complete; change nothing else.

---

## 7. Runtime power management drops the link

After a clean activation the GPU enumerated, bound, and then died ten seconds
later:

```
19:14:01  pcieport 0000:00:01.1: pciehp: Slot(0): Link Down
19:14:01  pcieport 0000:00:01.1: pciehp: Slot(0): Card not present
19:14:02  NVRM: Xid 79, GPU has fallen off the bus.
```

Cause:

```
/sys/bus/pci/devices/0000:00:01.1/power/control              auto
/sys/bus/pci/devices/0000:00:01.1/power/autosuspend_delay_ms 100
```

The root port runtime-suspends 100 ms after idle. Once the freshly-bound GPU
goes quiet the bridge drops to D3cold and the link never returns. **This is also
the boot failure** — booting with `egpu_enable=1` produces the identical
sequence. One root cause, two symptoms.

The fix took three iterations, and the progression is the useful part:

| Fix in place | Result |
|---|---|
| nothing | dies instantly, no log |
| `--release=minimal` | full success, then `Link Down` + `Xid 79` after ~10 s |
| `pcie_port_pm=off` | root port pinned — but the **endpoint** was still `auto`, `Xid 79` at 38 s |
| `+ pcie_aspm=off` | no `Link Down` at all; GPU still stopped answering |
| udev rule pinning **both** | no `Link Down`, no `Xid 79` |

**Port and endpoint must be pinned separately.** `pcie_port_pm=off` does not
cover the card. And the NVIDIA driver has its own runtime PM that reaches D3cold
independently of the PCI core's, so `NVreg_DynamicPowerManagement=0` is also
required. `xgm-egpu install-rules` writes both.

---

## PCIe link speed

**Unresolved, and the evidence is genuinely contradictory. Do not treat the
connectors as either exonerated or convicted.**

On **Windows**, with this exact DIY assembly:

- NVIDIA Control Panel reports **PCI Express x8 Gen3** — full XG Mobile spec
- **FurMark runs** at sustained maximum load without crashing
- **WHEA-Logger is empty** — zero corrected PCIe errors

On **Linux**, with the same hardware:

- The link **cannot complete training above Gen1**
- Held at Gen3 it died in ~18 seconds at idle
- At Gen1 it survived 15 minutes

Both observations are solid. They are not obviously compatible. Candidate
explanations, none confirmed:

- Windows' link training is firmware-mediated through the EC and takes a
  different path than Linux's.
- The link is genuinely marginal and Windows' error handling masks it.
- Something in Linux's retrain path is wrong for this bridge.

`--link-gen 1` is the working mitigation on the reference machine: roughly
2 GB/s, but stable. Setting ASPM to `performance` — which sounds correct and
keeps the link at top speed — made things strictly **worse**.

**If you have an official dock, please report your link speed.** That single
data point would resolve this, and it is the most useful thing anyone with
different hardware can contribute.

---

## Dead ends — do not repeat these

**The connector lock line is not the problem.** The AML validates the lock at
step 2 and refuses to continue if it is disengaged. Crash logs show `0xBE`
(sent before `SUMA`, step 3) followed by `0xC2`, and `egpu_enable` committed.
That is only possible if the step-2 lock check passed.

**`ec_sys` is useless on this model.** It loads, but all 256 bytes of
`/sys/kernel/debug/ec/ec0/io` read `0x00` whether the dock is attached or not.
A real EC is full of temperatures and battery state. ROG laptops route that
through WMI/ACPI methods instead. osy's EC offset `0x1C` is from a *different*
ASUS model, and EC RAM layouts are model-specific — reading zeros there is
proof the offset is wrong, not evidence about the lock.

To find the right offset empirically (pure reads, no risk):

```sh
sudo xgm-egpu ec --dump > /tmp/ec-attached.txt     # dock plugged in
sudo xgm-egpu ec --dump > /tmp/ec-detached.txt     # dock unplugged
diff /tmp/ec-attached.txt /tmp/ec-detached.txt
```

**"It boots with the dock attached, so the connectors are fine"** is an invalid
test. Booting with `egpu_enable=0` never switches the lanes to the XGM, so it
never exercises the link at all.

**"It is just slow, be patient"** is half right. The `off` path really does
block and complete. The `on` path, when it fails, kills the machine within
seconds. Slow and dead are different.

---

## Why Windows works where Linux does not

Windows does not go straight to `DEVS`. `GPUSwitchPlugin.dll` first queries the
dock's identity over HID (usage page `0xFF31`, usage `0x80`, validated with a
feature report `"^ASUS Tech.Inc.\0"`, then `GetEGPUID` = `5E CE 03`), writes the
result to `HKLM\SOFTWARE\ASUS\eGPU`, waits for the lock event `0xBA`, and
requires user confirmation via `GPUSwitchDialog.exe` before calling ACPI.

DIY docks need two shims purely to get past that: `XGMDriver` to make Armoury
Crate accept the dock as official, and `XGMActivator` to inject the GPU model
into the registry.

Linux performs none of that validation or settling and fires `DEVS` immediately.
Whether the missing identity handshake *matters* to the EC is unproven — the AML
checks EC state, not identity — but the timing difference alone (Windows waits
for lock verification and a human click) is a real candidate for the remaining
instability.

---

## Open questions

1. `Xid 154 GPU Reset Required` — the GPU enumerates and binds but will not
   initialise. Untried: power-cycling the dock at the mains (the dock's ATX
   supply means no host reboot has ever removed power from the card), and
   disabling Resizable BAR in the BIOS.
2. Why the link cannot train above Gen1 under Linux but does Gen3 under Windows.
3. Whether an official dock behaves differently from a DIY one on Linux.
4. What `egpu_enable` values `2` (`0x101`) and `3` (`0x201`) do.
