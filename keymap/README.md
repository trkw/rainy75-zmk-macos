# Keymap

`rainy75.keymap` is the source of truth for this setup. `./setup.sh` copies it
over the upstream default before building.

## Edit and flash

```bash
# from the repository root
$EDITOR keymap/rainy75.keymap
./setup.sh --ansi     # or --iso
./flash.sh
```

The first build after a keymap change is incremental, typically well under a
minute. `flash.sh` then uploads `build/zephyr/zmk.signed.bin` over USB (about
12 seconds).

## ZMK Studio and the source keymap

ZMK Studio saves changes **on the keyboard** (persisted settings), not to this
file, and it currently has no export/import. If you have used Studio, those
saved changes take priority over a newly flashed `.keymap` until you press
**Restore Stock Settings** in Studio.

Pick one source of truth:

- **Quick experiment:** ZMK Studio only.
- **Reproducible setup (recommended):** edit this file, rebuild, flash, then use
  **Restore Stock Settings** in Studio once to clear old Studio overrides.

## Mac-specific keys

The bottom row uses `&os_key LGUI` and `&os_key LALT`. With the runtime setting
`kb.os mac`, those become **Option** and **Command**:

```bash
.work/rainy75-zmk/.venv/bin/python \
  .work/rainy75-zmk/reverse/tools/rainy75_cfg.py set kb.os mac
```

There is no separate Windows layer and no Windows-only key in the default
keymap. `kb.gui_lock on` is available if you want the GUI/Command key to send
nothing (for example while gaming), but it is off by default.

## Common behaviors

| Binding | Meaning |
|---|---|
| `&kp A` | keypress |
| `&mo 1` | momentary layer while held |
| `&lt 1 SPACE` | tap Space, hold layer 1 |
| `&mt LCTRL A` | tap A, hold left Ctrl |
| `&trans` | fall through to the next layer |
| `&none` | do nothing |
| `&bt_sel_ble 0` | Bluetooth profile 1 (upstream helper) |
| `&out OUT_TOG` | toggle USB / Bluetooth |
| `&rgb RGB_TOG` | Rainy 75 RGB on/off |
| `&studio_unlock` | unlock ZMK Studio |

The file is the upstream keymap (Apache-2.0, see `NOTICE`) plus any local
changes. ANSI and ISO share it; the build flag selects the matrix and LED map.

ZMK reference: <https://zmk.dev/docs/keymaps>
