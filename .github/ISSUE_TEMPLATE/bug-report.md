---
name: Bug report
about: Something the tool did wrong, or a death that the docs do not cover
title: ""
labels: bug
---

What you ran, and what happened:

The run log (it survives reboots):

```
(xgm-egpu logs show)
```

`xgm-egpu detect` and `xgm-egpu status`:

```
```

If the machine died: the last 40 lines of `journalctl -k -b -1`.
