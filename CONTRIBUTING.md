# Contributing

This repo is **unmaintained by default** — published research from someone with
one machine and limited time. Issues will be read. Fixes may be slow. Forks are
encouraged and you do not need permission.

That said, some contributions are worth far more than others.

## The most valuable thing you can contribute

**A row in [HARDWARE.md](HARDWARE.md).** Even "it didn't work" is useful, and
"it died at stage 3 of `go`" is extremely useful. While the eGPU is active
(or as far as you got):

```sh
xgm-egpu report            # prints the row and the details an issue needs
xgm-egpu detect            # topology autodetection — the single most useful output
xgm-egpu logs show         # the last run, with its kernel log, if something went wrong
```

Set `DOCK="official XG Mobile 2021"` or `DOCK="osy Lite v0.6.1, I-PEX"` in
`/etc/xgm-egpu.conf` and the report fills the dock column in. Then either open
a pull request adding the row, or an issue with the "Hardware report" template.

**`xgm-egpu detect` getting your machine wrong is itself a bug worth reporting**,
separately from whether activation works. Detection is meant to need no
configuration on any ASUS host; a machine where it guesses wrong, or refuses to
guess, is something to fix in the script rather than work around in your config.

## Specific open questions

Answering any of these closes a real gap. In rough order of value:

1. **`Xid 154 GPU Reset Required`** — the GPU enumerates and binds but never
   initialises. If you have seen this on any eGPU and know the fix, that is the
   last thing standing between this repo and a working setup.

2. **Link speed on an official dock.** The reference machine trains at Gen3 x8
   under Windows but cannot get above Gen1 under Linux, with the same cable.
   One data point from an official dock would tell us whether that is the DIY
   connectors or Linux's retrain path.
   See [Findings § PCIe link speed](FINDINGS.md#pcie-link-speed).

3. **AMD eGPU behaviour.** The activation path is vendor-neutral but the entire
   teardown analysis is NVIDIA-specific. Does `amdgpu` eject cleanly?

4. **`egpu_enable` values 2 and 3** (`0x101`, `0x201`). Undocumented in the
   kernel, untested here.

5. **A machine where `ec_sys` actually works.** On the GV301QH all 256 bytes
   read zero. If you can find the real XGM state block offset for any ROG model,
   the lock-stability experiment becomes possible.

## Code

Keep the script's style: **the comments carry the reasoning.** Nearly every
constant and branch in `bin/xgm-egpu` exists because something specific went
wrong, and the comment says what. If you change behaviour, change the reasoning
with it. A diff that removes an explanation is worse than no diff.

Do not add anything that writes to `egpu_enable` without going through
`guarded_write()`. The whole point is that a stall must never wedge the caller's
shell or hold the ACPI hotplug mutex.

## Things this repo deliberately does not do

- **SteamOS / Bazzite / Decky integration.** Use
  [Kentronix57/Decky-Loader-XGMobile-Manager](https://github.com/Kentronix57/Decky-Loader-XGMobile-Manager).
  It handles the immutable root properly and this does not attempt to compete.
- **Install NVIDIA drivers.** Your distro does that better.
- **A GUI.**

## Upstream

Some of what is documented here is arguably kernel-side and belongs with
[asus-linux](https://asus-linux.org/) rather than in a shell script:

- `egpu_enable_current_value_store()` calls `armoury_pci_rescan()` while
  `kacpi_hotplug` holds `pci_rescan_remove_lock` performing the eject that same
  write triggered, so the writer blocks for the whole eject — and
  `current_value` reading `0` afterwards is actively misleading.
- Nothing guards against the eject stalling indefinitely in `nv_pci_remove()`'s
  `os_delay()` loop, which parks the writer in unkillable `D` state.

If you are better placed to file or patch that upstream than to fork this,
please do. It reaches far more people.
