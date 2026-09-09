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
cover the card. `xgm-egpu install-rules` pins both via udev.

This fixed the *PCI core's* runtime PM. It did **not** fix the ten-second death,
which turned out to be a different mechanism entirely — see §8. An earlier
version of this document claimed `NVreg_DynamicPowerManagement=0` closed "the
NVIDIA driver's own route into D3cold". The option was written to a file that
never took effect (§8 explains why), so that claim was never actually tested.

---

## 8. The ten-second link death: NVIDIA RTD3

**Root cause of the `Link Down` → `Xid 79` → `Xid 154` sequence. Found
2026-09-09, from the driver source.**

The eGPU came up, ran at Gen3 x8 with zero AER errors, and died exactly ten
seconds after `nvidia-drm` initialised — four times out of four:

| run | driver init | Link Down | delta |
|---|---|---|---|
| 31/07 | 19:13:51 | 19:14:01 | 10s |
| 09/09 | 09:33:46 | 09:33:56 | 10s |
| 09/09 | 10:03:53 | 10:04:03 | 10s |
| 09/09 | 10:15:59 | 10:16:09 | 10s |

That precision rules out signal integrity. It is a timer, and it is in
`src/nvidia/arch/nvalloc/unix/src/dynamic-power.c` of NVIDIA's open kernel
modules.

### The mechanism

NVIDIA "dynamic power management" (RTD3) lets a notebook dGPU power itself down
when idle. In `rmReadAndParseDynamicPowerRegkey()`:

```c
// If User has set some value, honor that value
if (*pRegkeyValue != NV_REG_DYNAMIC_POWER_MANAGEMENT_DEFAULT) { *pOption = *pRegkeyValue; return; }
// From GA102+, we enable RTD3 only if system is found to be Notebook
if ((chipId >= GA102) && rm_is_system_notebook()) { *pOption = FINE; return; }
```

The RTX 3060 is GA104 (≥ GA102). The Flow's DMI chassis type is 10 (Notebook).
So with the driver default, the eGPU gets **FINE** mode automatically. The
internal GTX 1650 is Turing, so it gets NEVER — which is why
`/proc/driver/nvidia/gpus/…/power` reads `Runtime D3 status: Not supported` on
it, and why the internal card never showed this problem.

In FINE mode an idle state machine runs:

```c
#define GC6_PRECONDITION_CHECK_TIME    ((NvU64)5 * 1000 * 1000 * 1000)   // 5s
#define GC6_BAR1_BLOCKER_CHECK_AND_METHOD_FLUSH_TIME (200 * 1000 * 1000)  // 200ms
```

1. 5s precondition check → `IDLE_INSTANT` becomes `IDLE_SUSTAINED`
2. Another 5s check → revoke user mappings
3. 200ms → `RmIndicateIdle` → `nv_indicate_idle` → GPU enters its low-power state

**5 + 5 + 0.2 = 10.2 seconds.** On a real Optimus laptop the platform expects
the GPU to drop its PCIe link for GC6 and brings it back on demand. On the XG
Mobile port, `pciehp` is live, sees the link drop, and treats it as **surprise
removal**. Hence `Xid 79` attributed to `irq/33-pciehp`, zero AER errors (the
drop was intentional, not a fault), then `Xid 154 GPU Reset Required`.

`power/control=on` on the device does not prevent this: your own watch log
shows `runtime_status` staying `active` throughout. RTD3 FINE does not need the
PCI core to suspend the device — the driver acts on the GPU directly.

### The fix, and the trap inside the fix

`NVreg_DynamicPowerManagement=0` (NEVER) disarms the entire state machine:
`CreateDynamicPowerCallbacks()` is never called, no timers exist, and
`RmConfigureUpstreamPortForRTD3()` never touches the root port. Getting that
value to the driver cost a day, for two stacked reasons:

**1. modprobe.d file ordering.** modprobe sorts all config files
lexicographically *regardless of directory*, and `-` (0x2D) sorts before `.`
(0x2E). So `nvidia-xgm-egpu.conf` in `/etc` loses to the distro's `nvidia.conf`
in `/usr/lib`, which on CachyOS (`cachyos-settings`) sets
`NVreg_DynamicPowerManagement=0x02`. A later-sorting duplicate (`zz-*.conf`) did
not win either. Only a **same-named** `/etc/modprobe.d/nvidia.conf` replaces the
distro file outright. `xgm-egpu install-rules` now writes that shadow,
preserving the distro file's other options.

**2. The initramfs.** Even with the shadow in place the loaded value stayed 2,
because:

```
[    1.393019] nvidia: loading out-of-tree module taints kernel.
[    6.201640] Starting Plymouth switch root service...
```

nvidia loads **before switch-root**, from the initramfs. On CachyOS the
`chwd` hardware-detection tool drops `MODULES+=(nvidia …)` into
`/etc/mkinitcpio.conf.d/10-chwd.conf` — invisible if you only check the main
file's `MODULES=()`. The `modconf` hook bakes whatever `modprobe.d` existed at
build time into the image. Nothing in `/etc/modprobe.d` matters until
`mkinitcpio -P` and a reboot.

`xgm-egpu install-rules` detects this and rebuilds. `xgm-egpu preflight`
reports the value of the **loaded** module — the only number that matters —
and `xgm-egpu on` refuses to activate while it is not 0.

### Why the `--no-reload` test was invalid

`--no-reload` skipped the tool's own `modprobe`, but the resident nvidia module
auto-binds to any new NVIDIA device the moment it enumerates. The driver was
never out of the picture. The flag now disables `/sys/bus/pci/drivers_autoprobe`
for the duration so the eGPU genuinely enumerates unbound.

---

## PCIe link speed

**Resolved 2026-09-09. The "Linux cannot train above Gen1" finding was a
measurement artifact.**

NVIDIA downshifts the PCIe link to Gen1 at idle (P8) and clocks back up under
load. Measured on the internal GTX 1650 with no eGPU involved:

```
idle:       P8, pcie.link.gen.current 1, 300 MHz,  3.3 W
under load: P0, pcie.link.gen.current 3, 1740 MHz, 19.1 W
```

Every "stuck at Gen1" reading in the earlier notes was taken at idle. The eGPU
itself has been observed at **Gen3 x8, P0, zero AER errors** on the same root
port, whose hardware ceiling is `max_link_speed 8.0 GT/s` (Gen3 — the 2021
GV301QH on Cezanne is PCIe 3.0; 2023 Flows do Gen4).

**Never read `current_link_speed` or `pcie.link.gen.current` at idle and call
it a ceiling.** Put load on the GPU first.

The observation that pinning Gen3 "died in ~18s at idle" was the RTD3 death of
§8 seen from a different angle, not a link-speed problem. `--link-gen` is no
longer needed and should not be used to work around it.

### Windows

Windows reports Gen3 x8 with FurMark stable and an empty WHEA log on the same
cable. That is consistent with everything above: the link is fine; the
difference was never the hardware.

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

1. **Does the eGPU survive with RTD3 genuinely disarmed?** The fix is
   identified and the tool now refuses to run without it, but the confirming
   run (loaded `DynamicPowerManagement: 0`, link up past ten seconds) has not
   yet been done.
2. Whether an official dock behaves differently from a DIY one on Linux.
3. What `egpu_enable` values `2` (`0x101`) and `3` (`0x201`) do.
4. Whether RTD3 can be disabled per-GPU rather than globally, so the internal
   dGPU keeps its battery saving. `NVreg_RegistryDwordsPerDevice` is the
   candidate; untested.
