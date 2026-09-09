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

## 8. The ten-second link death — RTD3 was NOT the cause

> **Corrected 2026-09-09, later the same day.** RTD3 is a real bug on this
> hardware and the fix below is worth keeping — but it does **not** cause the
> ten-second death. With `DynamicPowerManagement=0` confirmed loaded and
> `Runtime D3 status: Disabled` reported on the eGPU itself, the link still
> dropped at exactly ten seconds after `nvidia-drm` init, identically to every
> run before it. Five for five.
>
> ```
> 12:41:49  nvidia-drm initialized, fb1 framebuffer created
> 12:41:59  pciehp: Slot(0): Link Down        <- unchanged
> ```
>
> The GSP RPC dump that appears in the newer logs (`GSP_RM_CONTROL` with
> `ts_end 0`, `actively_polling: y`, `UCODE_LIBOS_PRINT`,
> `GSP_RUN_CPU_SEQUENCER`) is a **consequence**: the driver prints its RPC
> history when it notices the GPU has gone, and the in-flight RPC is the one
> that was outstanding at that moment. `Link Down` precedes all of it.
>
> **Resolved by that test, 2026-09-09.** With
> `/sys/bus/pci/drivers_autoprobe=0` so that neither `nvidia` nor
> `snd_hda_intel` binds, the eGPU enumerated and **held PCIe Gen3 x8
> indefinitely with zero AER errors**:
>
> ```
> drivers_autoprobe=0  (new devices will NOT be bound)
> eGPU enumerated at 0000:01:00.0
>   5s: still up    10s: still up    15s: still up
> ok  LINK SURVIVED 15s past driver init.
>     current   8.0 GT/s PCIe x8     AER  all zero
> ```
>
> Six runs with drivers bound died at exactly ten seconds. One run with
> nothing bound survived. **A driver kills it. The hardware, the connectors,
> the EC handshake and the lane switch are all fine** — see the connector
> section below, which this independently confirms for the third time.
>
> **Bisected to the display path, then to fbdev — 2026-09-09.**
>
> `xgm-egpu bind core` (nvidia only, display path unloaded): **survived**, Gen3
> x8, P0, `nvidia-smi` reading the card, AER zero. `xgm-egpu bind drm`
> (nvidia_modeset + nvidia_drm): **died at ~11s.** So GSP init and the core
> driver are fine; the display path kills it.
>
> **Two mechanism guesses ruled out from source, before testing them:**
>
> - *DRM connector poll* (`DRM_OUTPUT_POLL_PERIOD`, 10*HZ). No: nvidia-drm calls
>   `drm_kms_helper_poll_disable()` immediately after init (nvidia-drm-drv.c
>   :426) and marks every non-VGA connector `DRM_CONNECTOR_POLL_HPD`
>   (:689), so that poll never runs for it. `--no-drm-poll` exists only to
>   record that this was checked in code.
> - *"Correcting number of heads (0x00)"* at +9s. No: the **internal GTX 1650**
>   prints the same line, twice, ~10s apart, and works perfectly. It is normal
>   NVKMS head probing, not the trigger.
>
> **Leading hypothesis: the framebuffer console (`nvidia_drm.fbdev`).** Every
> death is immediately preceded by
>
> ```
> nvidia 0000:01:00.0: [drm] fb1: nvidia-drmdrmfb frame buffer device
> ```
>
> and the death itself is
>
> ```
> [drm:nv_drm_atomic_commit] *ERROR* [nvidia-drm] Flip event timeout on head 0
> ```
>
> which is the fbcon flip failing. When `fbdev=1`, nvidia-drm grabs NVKMS
> modeset ownership and installs a framebuffer console (nvidia-drm-drv.c :770);
> `fbdev=0` skips that block entirely. Community reports tie
> `nvidia_drm.fbdev=1` specifically to "flip event timeouts during display
> hotplugging," with `fbcon=map:0` / disabling fbdev as the workaround.
>
> **The test ladder** (each rung is one `xgm-egpu bind` after `on --no-reload`):
>
> | rung | what loads | prediction |
> |---|---|---|
> | `bind core` | nvidia only | SURVIVES (established) |
> | `bind modeset` | + nvidia_modeset, no DRM | survives (control — allocates nothing) |
> | `bind drm-nokms` | + nvidia_drm `modeset=0` | survives (no KMS, no fbcon) |
> | `bind drm-nofbdev` | + nvidia_drm `modeset=1 fbdev=0` | **survives if fbdev is the cause** |
> | `bind drm` | + nvidia_drm (fbdev on) | DIES (established) |
>
> ~~**fbdev tested and ruled out, 2026-09-09.** `xgm-egpu on --no-fbdev` died at ~9s, identical to every other run.~~
> **Withdrawn the same evening:** that run was a no-op — the resident
> `nvidia_drm` kept `fbdev=1` and the journal shows `fb1` being created on the
> eGPU. See the correction below. fbdev is untested and back to being the
> leading single cause.
>
> **Two mechanisms ruled out by hardware** (RTD3; the fbdev result is withdrawn above) **or source**
> (DRM poll, the heads message). The layer result stands: nvidia core alone
> survives indefinitely; nvidia_modeset + nvidia_drm dies at ~10s, with or
> without a monitor, with or without fbdev.
>
> **Next tests — built to produce a working configuration, not just a datum:**
>
> - `xgm-egpu on --no-kms`: nvidia_drm `modeset=0`. A render node and nothing
>   else — no KMS, no display-engine bring-up through DRM. If this survives,
>   **the eGPU is usable today** for CUDA, Vulkan and PRIME render offload onto
>   the laptop panel; only driving a monitor from the eGPU's own ports is lost.
> - `xgm-egpu on --mask-pciehp`: clears Hot-Plug Interrupt Enable, DLL State
>   Changed Enable and Presence Detect Changed Enable in the root port's Slot
>   Control (`CAP_EXP+0x18`, mask `0x1028`) for the duration of the watch.
>   Every death has Xid 79 raised from the pciehp IRQ thread — pciehp saw a
>   Link Down and tore the device down. If the drop is *momentary* (a retrain,
>   a PHY power event) this turns a fatal surprise-removal into a hiccup and
>   the device survives. If the link genuinely stays down the card simply goes
>   unresponsive, which the watch reports. Either answer is decisive.
> - `xgm-egpu bind modeset` / `bind drm-nokms`: split nvidia_modeset from
>   nvidia_drm, and "DRM device exists" from "KMS active".
>
> The survival watch now also samples `nvidia-smi` pstate / SM clock / memory
> clock / power / link gen every second, since the internal 1650 does the same
> periodic display probing and lives — whatever differs on the eGPU should be
> visible in its state right before the drop.
>
> ### Current leading hypothesis: a power transient at display-engine bring-up
>
> Decoding the last RPC in every dump — `0x731144` is
> `NV0073_CTRL_CMD_DFP_SET_ELD_AUDIO_CAPS` — the in-flight work at every death is
> HDMI-audio/VRR setup on the card's physical outputs. The **internal GTX 1650
> Mobile has no physical outputs at all** (`card0` has no connector entries in
> sysfs; the DP/HDMI/eDP on this machine belong to `card1`, the AMD iGPU), sits
> on the *same* hotplug root port, gets the *same* periodic NVKMS probing, and
> lives. The 3060 has HDMI + 3×DP and dies. So the display path is only lethal
> on the card that actually has a display engine to power up.
>
> osy's `Docs/Diary.md` documents the dock's power delivery as running with
> margins that were tuned during development: the GPU is fed by **two supplies
> in parallel** behind **hiccup-mode over-current protection** that "disables
> the FETs until a timer expires during an over-current condition," and earlier
> revisions had rails browning out and recovering in disconnect loops.
>
> Put together: powering up the display engine on a desktop card is a current
> step on top of P0. On a hand-built Lite board that step plausibly trips the
> OCP hiccup or sags a rail; the FETs cut, the slot browns out, the PCIe PHY
> resets, `pciehp` sees Link Down. **A brownout drops the link cleanly** — which
> is exactly why the AER counters read zero every time, where a signalling
> fault would have logged correctable errors first. Core-only survives because
> the display engine never powers up.
>
> `--cap-power` tested this from software, and **ruled it out**. With the
> graphics clock locked to 405 MHz and the power limit at its 100 W floor, the
> card sat at **23.5 W, flat, for the full 7 seconds** — drifting *down*
> (23.56 → 23.23 W), never up — at 29 °C, P0, Gen3, and the link died anyway.
> A display-init current step would show as a climb before the drop. There is
> none. Whatever this is, it is not the card drawing more power.
>
> ### It is NOT a kernel hang. The kernel is alive; the display stack freezes.
>
> This was misread for most of a day. The `--mask-pciehp` run settled it: the
> survival watch's fsync'd breadcrumb reached `end t=8 alive=0`, the journal
> flushed the Xid 79 / Xid 154 / Link Down lines at 15:00:21, and `capture` —
> which *was* armed — recorded nothing, because **there was no lockup to
> catch.** All three need a running kernel.
>
> What actually happens at the death, when run from a desktop session:
>
> ```
> 15:00:11  kwin_wayland: Failed to open drm device   (x3)
> 15:00:11  kwin_wayland: eglInitialize failed  EGL_NOT_INITIALIZED
> 15:00:21  NVRM: Xid 79, GPU has fallen off the bus
> 15:00:21  wireplumber: card removed
> ```
>
> kwin sees the new NVIDIA DRM device appear, opens it, fails EGL on it, and
> ten seconds later the device vanishes underneath it. **The compositor
> freezes.** Meanwhile fbcon hands the console from the dead `fb1` back to
> amdgpu with the wrong stride — the internal panel fills with a blue field and
> text fragments. Both displays are unusable, so it *looks* hung, and every
> time the power button was pressed on a live machine. That is also what the
> earlier "hard-cut journal" was: a live system power-cycled. No IOMMU faults
> across four boots (the eGPU sits in a translated DMA-FQ domain), so it is not
> stray DMA either.
>
> **Recovery without a power cycle:** `sshd` is running. From a phone or the
> Pi, `ssh` in and `sudo xgm-egpu off`. The display comes back.
>
> **pciehp is not the cause.** With its interrupts masked, `Xid 79` came
> *first* — the driver itself found the GPU unresponsive — and Link Down was
> logged after. The card genuinely stops answering; pciehp only reported it.
> Eight mechanisms eliminated.
>
> ### The evidence that has been destroyed every time
>
> Every death prints *"A GPU crash dump has been created. If possible, please
> run nvidia-bug-report.sh as root to collect this data before the NVIDIA
> kernel module is unloaded."* That dump is the GPU side's own account — GSP
> logs, RPC history, whatever fault the card saw — and it lives only in the
> driver's memory. Every reboot threw it away. The kernel is alive at t=8, so
> `xgm-egpu on` and `xgm-egpu bind` now run `nvidia-bug-report.sh --safe-mode`
> the instant the watch detects death, before any teardown, and save it to
> `/var/tmp/xgm-bugreport-<timestamp>.log.gz`. That file is the next thing
> to read.

> ### The strongest lead: GSP firmware (2026-09-09)
>
> Pulling the threads together: the death is a **GSP firmware hang**, not a
> link or power event.
>
> - With `--mask-pciehp`, `Xid 79` ("GPU has fallen off the bus" — the driver
>   read `0xffffffff` back from the GPU) was logged **before** Link Down. The
>   GPU stopped answering MMIO *first*; pciehp only noticed afterwards.
> - Every crash dump shows GSP mid-operation: `GSP_RM_CONTROL` in flight with
>   `actively_polling y`, and `GSP_RUN_CPU_SEQUENCER` / `UCODE_LIBOS_PRINT` in
>   the event history.
> - The card is in a rock-stable P-state at death (clocks and power flat, mem
>   pinned at 7501), so it is not a clock or power transition.
> - GSP failure on **Ampere laptop GPUs specifically** is a documented class
>   (open-gpu-kernel-modules issues #1058 "RTX 3080 laptop… Cannot initialize
>   GSP firmware", #543).
>
> The differential clinches it: `nvidia` core alone survives indefinitely
> (basic GSP RPCs are fine), and the death only appears once the **display**
> path is loaded — i.e. a *display* GSP RPC path falls over about eight seconds
> in, on a GPU that has physical display connectors (the internal 1650 Mobile
> has none and never dies).
>
> `NVreg_EnableGpuFirmware=0` forces the driver off GSP onto the legacy
> CPU-side RM, which performs display init through a completely different code
> path — no display GSP RPCs at all. It works **only on the proprietary
> module** (the open modules require GSP and ignore the parameter); this
> machine runs the proprietary `nvidia-580xx-dkms`, so it is available.
> `xgm-egpu gsp off` writes the modprobe shadow and rebuilds the initramfs;
> after `reload-driver` or a reboot, `gsp status` must show
> `EnableGpuFirmware 0`, then `on --no-fbdev`.
>
> This is the best-supported hypothesis of the investigation — it is the first
> that explains the Xid-79-before-Link-Down ordering and the GSP-in-flight
> dumps rather than merely tolerating them. If GSP-off still dies, the cause is
> below the firmware (the display engine touching the physical link/PHY), and
> `--no-kms` (a working render-only eGPU) becomes the endpoint.
>
> **`xgm-egpu capture`** arms the machine at runtime (no reboot): NMI watchdog
> on, hard/soft-lockup and hung-task and oops → panic, `panic=30` so it comes
> back on its own, EFI-backed pstore mounted, netconsole to the Pi best-effort.
> The next hang becomes a panic with a backtrace that survives the reboot.
> **Arm it before every activation from now on.** The survival watch also
> writes an fsync'd breadcrumb (`/var/tmp/xgm-last-run.txt`) every second.
>
> Seven mechanisms have now been eliminated. What remains testable in
> software: `--mask-pciehp` (stops pciehp starting the surprise-removal
> teardown — which may be both what makes the drop fatal *and* what hangs the
> box) and `--no-kms` (never powers the display engine; a working render-only
> eGPU). The next run should be `--mask-pciehp` with capture armed.

> ### Correction, 2026-09-09 evening: the display-layer options never applied
>
> Reading the journals of the three dying boots side by side with the driver
> source withdrew two "results" above and moved the investigation.
>
> **1. nvidia-drm attaches to the eGPU by itself.** The `on --no-fbdev
> --force-kill` run of 15:16, modules resident throughout, no modprobe between
> these lines:
>
> ```
> 244.327  xgm-egpu: Writing 1 to egpu_enable
> 244.354  [drm] [nvidia-drm] [GPU ID 0x00000100] Removing device     <- the 1650 ejected
> 248.766  nvidia 0000:01:00.0: enabling device (0000 -> 0003)      <- the 3060 probed
> 248.810  [drm] [nvidia-drm] [GPU ID 0x00000100] Loading driver      <- 44 ms later
> 250.942  [drm] Initialized nvidia-drm 0.0.0 for 0000:01:00.0 on minor 0
> 251.025  nvidia 0000:01:00.0: [drm] fb1: nvidia-drmdrmfb frame buffer device
> 261.518  pcieport 0000:00:01.1: pciehp: Slot(0): Link Down
> ```
>
> nvidia-drm registers `probe` and `remove` callbacks with nvidia-modeset's
> KAPI (`struct NvKmsKapiCallbacks { suspendResume, remove, probe }`,
> `nvkms-kapi.h`); the core module calls them from PCI probe/remove. The DRM
> device for the eGPU is created with whatever parameters `nvidia_drm` was
> **loaded** with — at boot, from the initramfs.
>
> **2. Therefore every `on --no-fbdev`, `--no-kms` and `--modeset-safe` run
> was a no-op.** With `--release minimal` the modules stay resident,
> `modprobe nvidia_drm fbdev=0` against a resident module is silently ignored
> (the same trap RTD3 set, documented in this very file), and the journal
> proves it: `fb1: nvidia-drmdrmfb frame buffer device` is created on the
> eGPU in the `--no-fbdev` run. *"fbdev tested and ruled out"* above is
> **withdrawn**. `fbdev=0`, `modeset=0` and the nvidia_modeset HDMI-FRL/VRR
> switches are all genuinely untested. The tool now persists them
> (`xgm-egpu drm nofbdev|nokms|safe` → modprobe.d + initramfs rebuild),
> `reload-driver --force-kill` or a reboot applies them, and `on` refuses to
> activate unless the **loaded** parameters match its flags. `bind drm*`
> refuses while nvidia_drm is resident for the same reason.
>
> **3. Why fbdev is the likeliest single cause.** Death is 10.5 s after
> "Initialized nvidia-drm", right after `fb1` is created, and is logged as
> `Flip event timeout on head 0` — an atomic commit on the fbcon framebuffer.
> With `fbdev=1` nvidia-drm grabs NVKMS modeset ownership at load and installs
> the fbdev client (`nvidia-drm-drv.c` :770). RM then spends seconds probing
> the 3060's four physical connectors; the resulting dpy-changed events reach
> nvidia-drm's deferred hotplug work (`nv_drm_handle_hotplug_event`) →
> `drm_kms_helper_hotplug_event` → the fb helper re-probes and **commits a
> mode on head 0 with nothing attached**. The internal 1650 prints its second
> "Correcting number of heads" at +10.7 s too and lives — it has no connector
> to commit to. `fbdev=0` removes the only DRM client that commits anything.
> It also keeps `modeset=1`, i.e. full PRIME (video-memory import, semaphore
> fences).
>
> **Tested for real at 19:30 — died identically.** `drm nofbdev` applied,
> `reload-driver`, `drm status` → `modeset=Y fbdev=N`, `on --no-fbdev`
> verified it, and the journal has no `fb1` line this time. Then:
>
> ```
> 15098.759  [nvidia-drm] [GPU ID 0x100] Loading driver
> 15100.454  Initialized nvidia-drm 0.0.0 for 0000:01:00.0 on minor 0
> 15100.46   kwin_wayland: eglInitialize failed ... Failed to open drm device   (x4)
> 15103-110  watch: P0, 1792 MHz, 7501 MHz, 31 W, Gen3 x8, 28 C - flat, every second, through 8 s
> 15111.078  pciehp: Slot(0): Link Down                                      <- 12.3 s after attach
> 15111.570  Xid 79 from irq/33-pciehp (inside pciehp_unconfigure_device -> nv_drm_dev_destroy)
> 15111.575  nvidia-modeset: Failed to query display engine channel state  (channels 2..7)
> ```
>
> Three things this run settles. **fbdev is out**, for real. **The link drops
> first**: Link Down is logged 0.5 s before the Xid, the Xid is raised from
> pciehp's own teardown path, and the GSP RPC history printed at death is a
> run of `FREE`s completing in 200-250 us — the firmware was healthy. **Seven
> display-engine channels were live** at death (the "Failed to query display
> engine channel state" lines are nvidia-modeset finding them gone). And the
> card is at rest the whole time: no clock, power or temperature movement at
> 1 Hz. Whatever the display engine does to this link, it does it without
> drawing power, and it takes 8-12 s.
>
> The run was made from the desktop; kwin opened the eGPU's `card0` and the
> whole session froze into the usual blue garbage at death, the box was
> power-cycled, and the journal ends at the modeset errors — no crash dump.
> `on` now warns and pauses when a compositor is live and a KMS path is
> requested. **Revised order: `drm nokms` (no display-engine channels at
> all; render node only), then `gsp off`, then `drm safe`.**
>
> **4. What `modeset=0` costs — measured, no root needed.** An `LD_PRELOAD`
> ioctl tracer on `vkcube` (xcb and native Wayland WSI) and `glxgears` under
> `prime-run`, on the internal 1650 (0 connectors, same shape as a render-only
> eGPU). What a PRIME client actually does on the NVIDIA render node:
> `GET_DEV_INFO`, `GEM_IMPORT_NVKMS_MEMORY` ×1 per swapchain image,
> `PRIME_HANDLE_TO_FD` (dma-buf export, exporter "drm"), and the `SEMSURF_*`
> fence ioctls. In the source, `GEM_IMPORT/EXPORT/ALLOC_NVKMS_MEMORY`,
> `GEM_EXPORT_DMABUF_MEMORY`, the dpy-id/permission ioctls return
> `-EOPNOTSUPP` without `DRIVER_MODESET`, every fence ioctl returns
> `-EOPNOTSUPP` with `pDevice == NULL`, `FENCE_SUPPORTED`/`DMABUF_SUPPORTED`
> return `-EINVAL`, and `GET_DEV_INFO` reports `supports_alloc = 0`. Emulating
> exactly that set from the shim: **vkcube (xcb) presents 300 frames, exit 0;
> glxgears renders at 120 FPS** — the userspace falls back to
> `GEM_IMPORT_USERSPACE_MEMORY` (system-memory buffers, not gated) and drops
> explicit fences; native-Wayland vkcube also presents, through a copy path
> that never touches the NVIDIA GEM. So render-only is a real endpoint for
> games via Xwayland/Proton, not only for CUDA.
>
> **5. The residual risk of `modeset=0`.** Every one of those clients also
> opens `/dev/nvidia-modeset` and issues `NVKMS_IOCTL_ALLOC_DEVICE` once, then
> `FREE_DEVICE` (a capability probe — driver and userspace are both
> 580.178.04, so it is not a version mismatch). It fails today because
> nvidia-drm's KAPI already owns the device. With `modeset=0` nothing owns it,
> and `AllocDevice` in `nvkms.c` has no privilege check
> (`nvAllocPerOpenDev(..., FALSE /* isPrivileged */)` after a successful
> `nvAllocDevEvo`), so a game could bring the display engine up from
> userspace — the same init, minus fbdev. Rehearse on the internal 1650
> (never dies): `drm nokms`, `reload-driver`, `prime-run vkcube --c 300`,
> and compare `dmesg | grep -c 'Correcting number of heads'` before and after.
> Making the node root-only is not a mitigation: with `open()` refused the
> client segfaults (shim-tested, exit 139).
>
> **6. The door userspace has into the display engine, and how it is sealed
> (21:00).** Rehearsal on the internal 1650 with `modeset=0` actually loaded
> (nvidia-drm initialised in 83 µs — no `allocateDevice`): 1.5 s after the
> reload the kernel printed "Correcting number of heads" anyway. The journal
> names the client: `kwin_wayland` created a Vulkan instance on the new device
> (`pci id for fd: 10de:1f9d`), the NVIDIA driver's probe allocated the display
> engine, then kwin rejected the device ("misses VK_EXT_external_memory_dma_buf").
> A `vkcube --wsi xcb` run added another allocation. So with `modeset=0` the
> eGPU's display engine would still come up — from userspace, within seconds
> of enumeration — and that bring-up is what dies.
>
> Making the node unopenable is not an option: with `open("/dev/nvidia-modeset")`
> failing (EACCES or ENOENT alike) GL is fine but the Vulkan driver **segfaults**,
> even `vulkaninfo`. What works is a **bind mount of `/dev/null` over the node**:
> clients open it, every NVKMS ioctl fails, and they carry on — `vkcube`,
> `vulkaninfo` and `glxgears` all ran normally with the allocation count flat
> (LD_PRELOAD-emulated, then the redirect variant). The driver source confirms
> nothing else can reach the engine: with `modeset=0` nvidia-drm never
> installs `master_set`, so opening the card node cannot call
> `grabOwnership(NULL)`. `on --no-kms` now seals the node before the write and
> `off` / `reload-driver` unseal it; `--no-seal` reproduces the client death.
>
> **7. The display engine is not the trigger. The HDMI audio codec is (21:30).**
> Run of 20:51: `modeset=0` loaded (nvidia-drm attached in 83 µs, no
> `allocateDevice`), `/dev/nvidia-modeset` sealed, RTD3 off, card flat at
> P0 / 31 W / Gen3 x8 / 28 °C for nine samples — **died at 10 s, identically.**
> The display engine never came up in that run, so every display hypothesis
> above (fbdev, KMS bring-up, connector probing, client allocation) is
> excluded at once. What the persistent kernel logs of all four deaths of the
> day (15:17, 19:30, 20:52, and the 20:51 run) show at the instant of death,
> every time:
>
> ```
> pcieport 0000:00:01.1: pciehp: Slot(0): Link Down
> snd_hda_codec_nvhdmi hdaudioC2D0: HDMI: invalid ELD buf size -1      (x17)
> snd_hda_intel 0000:01:00.1: GPU sound probed, but not operational: please add a quirk to driver_denylist
> ```
>
> `01:00.1` is the 3060's HDMI-audio function. With autoprobe on,
> `snd_hda_intel` binds it the moment it enumerates and starts probing the HDA
> codec inside the GPU (its PCM inputs register ~12 s before the death; the
> probe is still running at the death). The pieces that never fitted the
> display theory fit this one exactly:
>
> - the GSP RPC in flight at every death is `NV0073_CTRL_CMD_DFP_SET_ELD_AUDIO_CAPS`
>   — the RM servicing the HDA codec's ELD, not a modeset;
> - both configurations that survived (unbound; `bind core` with
>   `drivers_autoprobe=0`) had **no driver on 01:00.1**;
> - the internal GTX 1650 Mobile, which survives the same driver stack, **has
>   no audio function at all** (`lspci` shows only `01:00.0`);
> - `snd_hda_intel.power_save` is 0 here, so it is not the codec suspend timer;
>   it is the codec being alive on this card at all.
>
> Mechanism, as far as the logs allow: the HDA codec probe drives the GPU's
> HDA block, which asks the RM (through GSP) for ELD/audio capabilities on
> outputs the display engine has never initialised; about ten seconds into
> that exchange the GPU stops answering and the link drops. Whether the fault
> is GSP, the HDA block's power domain, or the board is still open — but the
> trigger is now a single PCI function that a render-only eGPU does not need.
>
> `on` therefore enumerates with autoprobe off, writes a `driver_override` no
> driver can match onto 01:00.1, binds `nvidia` to 01:00.0 by hand, and
> restores autoprobe (`--audio` to bind it as before; `bind audio` binds it
> later on purpose). A udev rule cannot do this: the kernel binds during the
> rescan, before udev sees the device.
>
> **8. Withdrawn: the audio codec was a correlation, and the real trigger is a
> PCIe speed change (21:05).** With the audio function fenced off (no driver
> on 01:00.1 — the "ALREADY bound" line in that run was a bug in the check;
> the kernel log shows no bind), `modeset=0`, NVKMS sealed, RTD3 off: died at
> 14 s. This time the per-second samples caught it:
>
> ```
> 10s P0, 1792, 7501, 31.41, 3, 29 link=8.0GT/sPCIe
> 11s <no smi>                     link=5.0GT/sPCIe     <- the link CHANGED SPEED
> 12s <no smi>                     link=5.0GT/sPCIe
> 21:05:26  pciehp: Slot(0): Card present / Link Up   <- data link went down and retrained
> 21:05:26  NVRM: Xid 79, GPU has fallen off the bus
> 21:05:28  pciehp: Slot(0): Link Down
> ```
>
> and at enumeration, before any driver touched it:
> `pciehp: Slot(0): Cannot train link: status 0x3883` — LnkSta with the LT
> (Link Training) bit set a full second after Link Up: the Gen3 training was
> still struggling. A speed change at or through 8 GT/s re-runs equalization;
> on these connectors it fell through to Detect, which resets the card, and the
> driver found its GPU gone. That is why the audio codec's ELD reads and the
> `DFP_SET_ELD_AUDIO_CAPS` RPC were always "in flight": they were simply what
> the driver happened to be doing when the bus vanished under it.
>
> Why the driver: the RM's `RMPcieLinkSpeed` registry key (`nvrm_registry.h`)
> holds per-generation ALLOW bits, and `osinit.c` sets ALLOW_GEN3 only when the
> module parameter `NVreg_EnablePCIeGen3=1` is given. On a platform it does not
> recognise the RM's allowed speed is below what the hardware trained, and
> ~10 s after init it brings the link down to what it allows — 8.0 → 5.0 GT/s,
> exactly the sample. An unbound card is never asked to change speed and holds
> Gen3 x8 indefinitely; the internal 1650's link is a real laptop link that
> survives a retrain. Every earlier "10-second" death was this retrain.
>
> Two ways to remove the mismatch, both now in the tool:
> - `on --link-gen 2`: pin the root port to Gen2 before the switch and re-pin
>   (without retraining if already there) before anything binds. The link
>   trains at 5 GT/s, needs no equalization, matches the RM's allowed speed —
>   nothing ever retrains. Gen2 x8 is 4 GB/s, Thunderbolt-eGPU bandwidth.
> - `pcie gen3` (`NVreg_EnablePCIeGen3=1`): tell the RM Gen3 is allowed so it
>   never pulls the link down. Full Gen3 x8 if the link's own training holds.
>
> The watch now prints a loud line the second the sampled link speed changes.
>
> ### RESOLVED, 2026-09-09 21:31: it was the driver retraining the link
>
> With the display engine fully excluded (`modeset=0` **and** the NVKMS door
> sealed) the card still died at ~10 s, so the whole display-path thread
> above was a red herring, however well it fitted. The watch's link samples
> gave the real event: every death is preceded by the link going
> **8.0 → 5.0 GT/s** while the GPU sits in a flat P0 — the driver retraining
> the link down, about ten seconds after init, which is when the RM's
> post-init perf state decays and it lowers the PCIe generation with it (the
> internal 1650 sits at Gen2 for the same reason). A retrain at 8 GT/s needs
> equalization, which these substituted connectors do not complete (the
> kernel's `Cannot train link` at enumeration was the same fact, read the
> other way). An unbound card, or the core module alone, never asks for a
> retrain, which is why both held Gen3 x8 indefinitely.
>
> The fix removes every reason to retrain, and two runs (21:31 from a TTY,
> 21:58 from the desktop) held Gen3 x8, P0, 40 W, zero AER, with
> `nvidia-smi` and PRIME render offload working:
>
> 1. `pcie gen3` — `NVreg_EnablePCIeGen3=1`, so the RM does not treat Gen3 as
>    forbidden on an unrecognised platform and pull the link down for policy.
> 2. `--freeze-link` — `nvidia-smi -lgc/-lmc` at the card's maximum so it never
>    leaves P0 (the perf-driven switch never fires), and the Hardware
>    Autonomous Speed/Width Disable bits (`LnkCtl2 |= 0x60`) on the GPU and
>    the root port. Log of the working run:
>
>    ```
>    link now: 8.0 GT/s PCIe x8
>    graphics clock locked at 2115 MHz — the GPU stays in P0
>    memory clock locked at 7501 MHz
>    0000:01:00.0: LnkCtl2 0x0003 -> 0023  (hardware-autonomous speed/width changes disabled)
>    0000:00:01.1: LnkCtl2 0x0003 -> 0023
>    15s: pstate,sm,mem,W,gen,C = P0, 1995, 7501, 40.81, 3, 36
>    LINK SURVIVED 15s past driver init.
>    ```
> 3. `drm nokms` with the sealed `/dev/nvidia-modeset`, RTD3 off, runtime PM
>    pinned — the configuration the fix was tested in. Whether the full
>    display path (`modeset=1`) also survives now that nothing retrains the
>    link is the obvious next experiment and is **untested**; on this
>    machine nobody needs the eGPU's ports.
>
> What the retrain-death chain leaves unexplained is only the exact policy
> that chose Gen2 ten seconds in; it lives in the RM and is not readable from
> here. Everything else — the flat P0 at death, the clean drop with zero AER,
> core-only surviving, `--link-gen 1` surviving for minutes, `--cap-power`
> dying (it never touched the link), fbdev/modeset/door making no difference
> — is what a policy-driven speed change on a link that cannot equalise at
> 8 GT/s looks like. Also fixed along the way, because they bit: the
> compositor holding the internal dGPU (`desktop pin`), `--force-kill`
> closing the user's apps (they are relaunched), a display manager left
> stopped (TTY handoff), and evidence lost to reboots (`logs`).
>
> **9. RM does not consider this an external GPU.** `RmCheckForExternalGpu`
> (`osinit.c`) sets `PDB_PROP_GPU_IS_EXTERNAL_GPU` only for an Intel
> Thunderbolt 3 bridge *and* a surprise-hotplug-capable slot; the XGM root
> port is AMD. The only consequence found is skipping the platform request
> handler load (`kern_perf.c`), so nothing here changes the diagnosis; noted
> so nobody chases it.

### The RTD3 finding itself (real, worth keeping, not the cause)

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

**Testing the fix without a reboot.** When nothing holds the GPU (refcount on
`nvidia` equals the count of its dependent modules, no open fds), the stack can
be unloaded and reloaded in place and picks up the new modprobe.d immediately,
sidestepping the initramfs question entirely: `xgm-egpu reload-driver`. It
refuses if anything holds the device. This is not the fatal `--release unload`
path from §6 — nothing is switching, `egpu_enable` is 0, the bus is static.

Once the driver is confirmed at 0, `xgm-egpu on` watches the link for 15
seconds after the bind and reports `LINK SURVIVED` or the second it died, so
the confirming run states its own result. Verified nothing can re-arm FINE
after the regkey says NEVER: the only re-instatement (`b_fine_not_supported`,
line 1777) can be set solely from FINE mode.

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
4. ~~Whether RTD3 can be disabled per-GPU so the internal dGPU keeps its battery
   saving.~~ Moot on the reference machine: the Turing GTX 1650 reports
   `Runtime D3 status: Not supported`, so it never used RTD3 and global
   `DynamicPowerManagement=0` costs nothing. On a host whose internal dGPU
   *does* support RTD3, `NVreg_RegistryDwordsPerDevice` is the candidate.
