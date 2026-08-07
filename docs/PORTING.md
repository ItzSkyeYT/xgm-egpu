# Porting to another machine

**You should not need this file.** Topology is autodetected from sysfs at
startup. Run:

```sh
xgm-egpu detect
```

If it prints the right thing, you are done — there is nothing to configure.

This document exists for two reasons: to explain what detection does so you can
tell whether it got it right, and to help if it did not.

---

## What gets detected, and how

Three values, all derived from sysfs. No root, no `lspci` parsing, nothing that
can perturb the bus.

### `INTERNAL_DGPU` — the discrete GPU sharing the XGM's lanes

Every PCI display-class device (`class` = `0x03xxxx`) that is **not** the
firmware's primary adapter. `boot_vga=1` marks that primary, which on every ASUS
laptop in scope is the APU's integrated graphics.

```
0000:01:00.0  0x10de:0x1f9d  boot_vga=0  parent=0000:00:01.1   <- internal dGPU
0000:08:00.0  0x1002:0x1638  boot_vga=1  parent=0000:00:08.1   <- iGPU, skipped
```

**Empty on hosts that have no internal dGPU (ROG Ally). That is a supported
configuration, not a failure** — see below.

### `INTERNAL_DEVID` — its device ID

Read straight from `/sys/bus/pci/devices/<bdf>/device`.

Needed because **the eGPU frequently claims the exact address the internal dGPU
just vacated.** On the reference machine the RTX 3060 came up at `0000:01:00.0`,
the GTX 1650's old slot. That is expected: the XG Mobile port *shares those
lanes*, which is why activation ejects the internal card at all. Everything here
identifies the eGPU by device ID, never by address, and you should too if you
build on this.

### `ROOT_PORT` — the bridge hosting the slot

The internal dGPU's parent bridge, since the XGM shares its lanes.

With no internal dGPU there is nothing to walk up from, so detection falls back
to `/sys/bus/pci/slots/` — the hotplug slots `pciehp` registers. The slot address
is the *downstream* bus, so the port is the bridge whose `secondary_bus_number`
matches. If exactly one such slot is unoccupied, that is the XGM port.

---

## Hosts with no internal dGPU (ROG Ally)

**The hard half of this problem does not exist for you.**

Nothing shares the XGM's lanes, so activation triggers no ACPI eject. That means
no `nv_pci_remove()` stall, no 856-second hang, no `WAT1()` teardown-ordering
trap, and no unkillable `D`-state process.
[Findings §4](../FINDINGS.md#4-what-actually-stalls-the-eject) and
[§6](../FINDINGS.md#6-less-teardown-not-more) are background reading for you, not
instructions. The release path is a no-op and says so:

```
==> Releasing the internal dGPU before the ACPI eject
==>   no internal dGPU on this host — nothing to unbind
```

What still applies, and will bite if you skip it:

- [§7 Runtime power management](../FINDINGS.md#7-runtime-power-management-drops-the-link)
  — you *will* hit `Link Down` / `Xid 79` without `xgm-egpu install-rules`
- [§1 Persistent EC state](../FINDINGS.md#1-egpu_enable-is-persistent-ec-state)
  and all of [RECOVERY.md](RECOVERY.md)
- [§3 Slow is not stuck](../FINDINGS.md#3-blocking-is-structural-and-slow-is-not-stuck)

**Handhelds make recovery harder, not easier.** Fewer ports, no easy TTY, and a
non-booting Ally with committed EC state is genuinely unpleasant to dig out of.
Read [RECOVERY.md](RECOVERY.md) before your first attempt, not after.

---

## When detection cannot decide

The one ambiguous case: **no internal dGPU, and more than one empty hotplug
slot.** There is nothing to disambiguate them with, so it refuses to guess rather
than picking wrong:

```
 !  several empty hotplug slots; cannot tell which is the XGM port:
    0000:00:01.1
    0000:00:02.2
 !  set ROOT_PORT in /etc/xgm-egpu.conf or pass --root-port
```

This degrades rather than fails. `install-rules` still writes the vendor rule
that pins the card itself; only the bridge goes unpinned. Activation still works.

To resolve it, find which port the XGM is on:

```sh
# with the dock attached and active, the eGPU's parent IS the root port
basename "$(dirname "$(readlink -f /sys/bus/pci/devices/<egpu-bdf>)")"

# or check which ports are hotplug-capable and x8-capable
sudo lspci -vv -s 0000:00:01.1 | grep -iE 'HotPlug|Slot|LnkCap'
```

Then persist it:

```sh
# /etc/xgm-egpu.conf
ROOT_PORT=0000:00:01.1
```

---

## Overriding anything

Three routes, in increasing precedence:

```sh
# 1. config file
cat /etc/xgm-egpu.conf
ROOT_PORT=0000:00:01.1
INTERNAL_DGPU=0000:01:00.0
INTERNAL_DEVID=0x1f9d

# 2. environment
ROOT_PORT=0000:00:01.1 xgm-egpu status

# 3. flags
xgm-egpu on --root-port 0000:00:01.1 --internal-dgpu 0000:01:00.0
```

Detection only fills in blanks — anything you set is left alone.

### The state cache

`/var/lib/xgm-egpu/topology.conf`, written when running as root while
`egpu_enable=0`.

Once the eGPU is active it occupies the internal dGPU's address, so "which
display device is the internal one" stops being answerable by looking at the bus.
The cache preserves the answer from when it *was* answerable. Delete it to force
re-detection; it is regenerated automatically.

---

## Kernel requirements

```sh
lsmod | grep -E 'asus_armoury|asus_wmi'
ls /sys/class/firmware-attributes/asus-armoury/attributes/
zgrep -E 'ASUS_ARMOURY|ASUS_WMI|HOTPLUG_PCI_PCIE' /proc/config.gz
```

You want `CONFIG_ASUS_ARMOURY`, `CONFIG_ASUS_WMI` and `CONFIG_HOTPLUG_PCI_PCIE`.

If `asus-armoury` is missing but `/sys/devices/platform/asus-nb-wmi/egpu_enable`
exists, you are on an older kernel using the deprecated path. The `$FW` paths
near the top of the script need repointing; everything else applies unchanged.

---

## AMD eGPUs

Untested. The activation path is vendor-neutral — it is an EC/ACPI transaction
and does not care what card is on the other end — but everything in this repo
about `nvidia-powerd`, `nv_pci_remove()`, `NVreg_DynamicPowerManagement` and
`Xid` codes is NVIDIA-specific, including the udev rule's `ATTR{vendor}=="0x10de"`
match.

`--release minimal` should still be right, since the
[`WAT1()` reasoning](../FINDINGS.md#6-less-teardown-not-more) is about the
firmware needing the OS to complete a real eject, not about which driver does it.

Reports welcome.

---

## Please report what you find

Whether detection worked or not, a hardware report is the most useful
contribution to this repo. Paste `xgm-egpu detect` and `xgm-egpu status` into an
issue — see [CONTRIBUTING.md](../CONTRIBUTING.md).
