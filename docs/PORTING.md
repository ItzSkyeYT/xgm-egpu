# Porting to another machine

`bin/xgm-egpu` currently hardcodes three values for the reference ROG Flow X13
GV301QH. They are at the top of the script, lines 23–25:

```bash
INTERNAL_DGPU=0000:01:00.0        # GTX 1650 Mobile
ROOT_PORT=0000:00:01.1            # bridge hosting that slot, and the XGM's lanes
INTERNAL_DEVID=0x1f9d             # TU117M
```

Autodetection is not implemented yet. Editing these three lines is the entire
porting process.

---

## First: does your machine have an internal dGPU?

This determines how much work you have to do, and it is a much bigger fork than
it looks.

```sh
lspci -nn | grep -iE 'vga|3d|display'
```

### No internal dGPU — ROG Ally, and similar

**The hard half of this problem does not exist for you.**

There is no dGPU to eject, so there is no `nv_pci_remove()` stall, no 856-second
hang, no `WAT1()` teardown-ordering trap, and no unkillable `D`-state process.
[Findings §4](../FINDINGS.md#4-what-actually-stalls-the-eject) and
[§6](../FINDINGS.md#6-less-teardown-not-more) are informational only for you.

The release path is a **no-op by construction**: `unbind_internal()` finds no
driver at the configured path and returns early, and `pci_remove_internal()`
only runs at `--release remove`, which you should not use.

So of the three constants, **only `ROOT_PORT` matters for you** — it is used for
runtime-PM pinning, which you *will* need. Set `INTERNAL_DGPU` and
`INTERNAL_DEVID` to anything; they will never be dereferenced.

What still applies to you, and will bite if you skip it:

- [§7 Runtime power management](../FINDINGS.md#7-runtime-power-management-drops-the-link) — you will hit `Link Down` / `Xid 79` without the udev rules
- [§1 Persistent EC state](../FINDINGS.md#1-egpu_enable-is-persistent-ec-state) and all of [RECOVERY.md](RECOVERY.md)
- [§3 Slow is not stuck](../FINDINGS.md#3-blocking-is-structural-and-slow-is-not-stuck)

**Handhelds make recovery harder, not easier.** Fewer ports, no easy TTY, and a
non-booting Ally with committed EC state is genuinely unpleasant to dig out of.
Read [RECOVERY.md](RECOVERY.md) before your first attempt, not after.

### Internal dGPU present — Flow X13, X16, Zephyrus, etc.

You need all three constants correct, and everything in
[FINDINGS.md](../FINDINGS.md) applies.

---

## Finding your values

### `INTERNAL_DGPU` and `INTERNAL_DEVID`

Your internal discrete GPU — the one that shares lanes with the XG Mobile port:

```sh
lspci -nn | grep -iE '3d controller|vga.*nvidia|vga.*amd'
```

```
01:00.0 3D controller [0302]: NVIDIA Corporation TU117M [GeForce GTX 1650 Mobile] [10de:1f9d]
        ^^^^^^^^^^                                                                      ^^^^
        INTERNAL_DGPU=0000:01:00.0                                   INTERNAL_DEVID=0x1f9d
```

On a laptop with a MUX, the internal dGPU is usually the `3D controller`
(render-offload) or `VGA compatible controller` on bus 01.

### `ROOT_PORT`

The PCIe bridge hosting that device. Walk up the sysfs tree:

```sh
basename "$(dirname "$(readlink -f /sys/bus/pci/devices/0000:01:00.0)")"
```

Or read it off the topology:

```sh
lspci -t -nn
```

Confirm it is a hotplug-capable port:

```sh
sudo lspci -vv -s 0000:00:01.1 | grep -iE 'HotPlug|Slot|LnkCap'
```

You want `HotPlug+`. If the bridge you found is not hotplug-capable, you have
the wrong one.

---

## The address trap

**The eGPU frequently claims the exact address the internal dGPU just vacated.**

On the reference machine the RTX 3060 came up at `0000:01:00.0` — the GTX 1650's
old slot. That is expected: the XG Mobile port *shares those lanes*, which is
why activation ejects the internal card in the first place.

**Identify the eGPU by device ID, never by address.** `xgm-egpu` does this
internally. If you write your own tooling around it, do the same, or you will
end up operating on whichever card happens to be there.

---

## AMD eGPUs

Untested here. The activation path is vendor-neutral — it is an EC/ACPI
transaction and does not care what card is on the other end. But everything in
this repo about `nvidia-powerd`, `nv_pci_remove()`, `NVreg_DynamicPowerManagement`
and `Xid` codes is NVIDIA-specific.

With `amdgpu` the eject may behave differently — better or worse, nobody has
checked. `--release minimal` is still the right starting point, since the
[`WAT1()` reasoning](../FINDINGS.md#6-less-teardown-not-more) is about the
firmware needing the OS to complete a real eject, not about which driver does it.

Reports welcome.

---

## Kernel requirements

```sh
# the driver
lsmod | grep -E 'asus_armoury|asus_wmi'

# the interface
ls /sys/class/firmware-attributes/asus-armoury/attributes/

# config
zgrep -E 'ASUS_ARMOURY|ASUS_WMI|HOTPLUG_PCI_PCIE' /proc/config.gz
```

You want `CONFIG_ASUS_ARMOURY`, `CONFIG_ASUS_WMI` and `CONFIG_HOTPLUG_PCI_PCIE`.

If `asus-armoury` is missing but `/sys/devices/platform/asus-nb-wmi/egpu_enable`
exists, you are on an older kernel using the deprecated path. The script's
`$FW` paths at lines 18–21 need repointing, but everything else applies.

---

## Please report what you find

A porting report is the most useful contribution to this repo. Include your
`xgm-egpu status` output, `lspci -nn`, your three constants, and what happened.
See [CONTRIBUTING.md](../CONTRIBUTING.md).
