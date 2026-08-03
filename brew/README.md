# brew

Tiered Brewfiles (pattern borrowed from [linkarzu/dotfiles-latest](https://github.com/linkarzu/dotfiles-latest/tree/main/brew)).
Install in order of need — a new machine only strictly needs `00-base`.

| File | What |
| --- | --- |
| `00-base.Brewfile` | Essentials for this dotfiles setup: shell + CLI, terminal (ghostty), system-level (yabai/skhd/sketchybar/borders, fonts) |
| `10-desktop.Brewfile` | Extra desktop apps (alternate terminals, media, utilities) |
| `15-ai.Brewfile` | Coding-agent tooling (herdr, rtk) |
| `20-dev.Brewfile` | Personal dev tools, VS Code extensions |

Work (Nitra) packages — heroku, stripe, ngrok, postico, postman, redis GUIs — are
deliberately not tracked here; install those per-machine or from a work Brewfile.

## Install

```sh
# One tier
brew bundle --file=~/dotfiles/brew/00-base.Brewfile

# Everything
for f in ~/dotfiles/brew/*.Brewfile; do brew bundle --file="$f"; done
```

## Check drift / update

```sh
# What's in a Brewfile but not installed
brew bundle check --verbose --file=~/dotfiles/brew/00-base.Brewfile

# Everything installed on this machine, to diff against these files
brew bundle dump --file=- | less
```

New packages: add a line to the right tier, then `brew bundle --file=<tier>`.
