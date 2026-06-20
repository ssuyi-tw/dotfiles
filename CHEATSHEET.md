# Keybinding Cheat Sheet

My day-to-day keyboard shortcuts across the desktop. Window-manager bindings are
generated from [`skhd/.config/skhd/skhdrc`](skhd/.config/skhd/skhdrc) and
[`yabai/.config/yabai/yabairc`](yabai/.config/yabai/yabairc) -- edit those, then
update this doc.

Chords are joined with `+` (e.g. `shift + alt + h`). Space-separated keys are
typed in sequence (e.g. `leader f`, `z c`).

---

## yabai + skhd (window manager)

### Windows

| Shortcut                  | Action                                            |
| ------------------------- | ------------------------------------------------- |
| `alt + f`                 | **Maximize focused window in its space (toggle)** |
| `alt + h/j/k/l` or arrows | Focus window W/S/N/E                              |
| `shift + alt + h/j/k/l`   | Swap window W/S/N/E                               |

### Spaces (desktops)

| Shortcut                  | Action                            |
| ------------------------- | --------------------------------- |
| `alt + 1`..`9`, `alt + 0` | Focus space 1-10                  |
| `alt + x`                 | Focus recent space                |
| `shift + alt + 1`..`9`    | Send window to space 1-9 + follow |

### Apps

| Shortcut          | Action                |
| ----------------- | --------------------- |
| `alt + return`    | Open Ghostty terminal |
| `shift + alt + r` | Reload yabai          |
| `alt + y`         | Mirror tree Y-axis    |

---

## yabai -- less common

Everything below works but I rarely use it. Source of truth is still
[`skhdrc`](skhd/.config/skhd/skhdrc).

### Move / resize

| Shortcut                 | Action                           |
| ------------------------ | -------------------------------- |
| `shift + cmd + h/j/k/l`  | Warp (move in tree) W/S/N/E      |
| `shift + alt + a/s/w/d`  | Grow window (left/bot/top/right) |
| `shift + cmd + a/s/w/d`  | Shrink window                    |
| `shift + alt + 0`        | Balance window sizes             |
| `shift + ctrl + a/s/w/d` | Nudge floating window by 20px    |

### Floating window grid

| Shortcut              | Action                                        |
| --------------------- | --------------------------------------------- |
| `alt + t`             | Float + center (4x4 grid)                     |
| `shift + alt + up`    | Fill screen                                   |
| `shift + alt + left`  | Fill left half                                |
| `shift + alt + right` | Fill right half                               |
| `alt + p`             | Picture-in-picture (sticky + topmost, corner) |

### Layout / tree

| Shortcut               | Action                      |
| ---------------------- | --------------------------- |
| `alt + r`              | Rotate tree 90 degrees      |
| `shift + alt + y`      | Mirror tree X-axis          |
| `alt + e`              | Toggle split direction      |
| `ctrl + alt + a`       | Layout: bsp                 |
| `ctrl + alt + d`       | Layout: float               |
| `ctrl + alt + h/j/k/l` | Set insertion point W/S/N/E |
| `alt + a`              | Toggle padding + gap        |

### Window toggles

| Shortcut          | Action                       |
| ----------------- | ---------------------------- |
| `shift + alt + f` | Native macOS fullscreen      |
| `alt + o`         | Toggle topmost (float above) |
| `shift + alt + b` | Toggle window border         |

### Displays (monitors)

| Shortcut                     | Action                                           |
| ---------------------------- | ------------------------------------------------ |
| `ctrl + alt + x` / `z` / `c` | Focus recent / prev / next display               |
| `ctrl + alt + 1` / `2` / `3` | Focus display 1 / 2 / 3                          |
| `ctrl + cmd + x` / `z` / `c` | Send window to recent/prev/next display + follow |
| `ctrl + cmd + 1` / `2` / `3` | Send window to display 1/2/3 + follow            |

### Mouse (modifier from `yabairc`)

| Action              | Effect        |
| ------------------- | ------------- |
| `ctrl` + drag       | Move window   |
| `ctrl` + right-drag | Resize window |

### Notes on resolved bindings

skhd applies the **last** matching definition in the file. Two former duplicate
bindings were disabled so the intended action wins:

- **`alt + x`** -> _focus recent space_. The old _mirror tree X-axis_ binding on
  the same key was moved to `shift + alt + y`.
- **`shift + alt + 0`** -> _balance window sizes_. The old _send window to space
  10_ binding is commented out (only spaces 1-7 exist, so it had no valid target).

---

## Cursor (Vim mode)

`leader` = `\` (backslash). From [`cursor/.../settings.json`](cursor/Library/Application%20Support/Cursor/User/settings.json).

| Shortcut                | Action                           |
| ----------------------- | -------------------------------- |
| `leader f`              | Format document                  |
| `leader leader`         | Toggle line comment              |
| `leader r`              | Rename symbol                    |
| `leader p` / `leader u` | Pin / unpin editor               |
| `leader t`              | Focus terminal                   |
| `z c` / `z o`           | Fold / unfold                    |
| `z a`                   | Toggle fold                      |
| `z m` / `z r`           | Fold all / unfold all            |
| `j` / `k`               | Move by display line (`gj`/`gk`) |

---

## Ghostty

No custom keybindings -- uses defaults. Common ones:

| Shortcut                         | Action           |
| -------------------------------- | ---------------- |
| `cmd + d`                        | Split right      |
| `cmd + shift + d`                | Split down       |
| `cmd + alt + up/down/left/right` | Focus split      |
| `cmd + t`                        | New tab          |
| `cmd + 1`..`8`                   | Go to tab N      |
| `cmd + ,`                        | Reload config    |
| `cmd + k`                        | Clear scrollback |

---

## Arc browser

| Shortcut                                 | Action                         |
| ---------------------------------------- | ------------------------------ |
| `ctrl + tab` / `ctrl + shift + tab`      | Cycle tabs (back-and-forth)    |
| `cmd + [` / `cmd + ]`                    | Back / forward                 |
| `cmd + l` / `cmd + t`                    | Command bar / new tab          |
| `cmd + s`                                | Toggle sidebar                 |
| `cmd + alt + right` / `cmd + alt + left` | Next / previous tab in sidebar |
| `cmd + ctrl + 1`..`9`                    | Switch Space                   |
| `cmd + w` / `cmd + shift + t`            | Close tab / reopen closed      |

### Vimium (in-page)

| Shortcut         | Action                          |
| ---------------- | ------------------------------- |
| `j` / `k`        | Scroll down / up                |
| `d` / `u`        | Scroll half-page down / up      |
| `gg` / `G`       | Top / bottom of page            |
| `f` / `F`        | Open link hint (same / new tab) |
| `H` / `L`        | History back / forward          |
| `J` / `K`        | Previous / next tab             |
| `x` / `X`        | Close tab / restore tab         |
| `o` / `O`        | Open URL (current / new tab)    |
| `/` then `n`/`N` | Find, next / previous match     |
| `yy`             | Copy current page URL           |
| `?`              | Show all Vimium bindings        |

---

## Raycast

| Shortcut  | Action       |
| --------- | ------------ |
| `alt + d` | Open Raycast |
