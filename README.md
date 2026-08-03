# dotfiles

Some configuration I am using.

See [CHEATSHEET.md](CHEATSHEET.md) for my desktop and editor keyboard shortcuts.

TL;DR; basic zsh setup

```sh
cd $HOME && git clone https://github.com/elic-eon/dotfiles.git
brew install stow fzf jq yq bat delta lsd ripgrep fd starship
cd $HOME/dotfiles && stow sheldon
```

## Installation

### Clone This Repo

```sh
cd $HOME
git clone git@github.com:elic-eon/dotfiles.git
```


### Install GNU Stow

Managing dotfiles using [GNU Stow](https://www.gnu.org/software/stow/)

`brew install stow`

### Install packages

For example, install `wezterm` package:

```sh
cd ~/dotfiles
stow wezterm
```

Soft link all files under `dotfiles/wezterm`

### Uninstall packages

Unlink all file in the package folders

```sh
cd ~/dotfiles
stow -D wezterm
```

## Packages

Recent setup

### Fonts

Hack Nerd font

```sh
brew install font-hack-nerd-font
```

SF symbols

```sh
brew install --cask sf-symbols
```

### utils

```sh
brew install fzf jq yq bat delta lsd ripgrep fd starship
```

### wezterm

```sh
brew install wezterm
```

install config

```sh
stow wezterm
```

### zsh

Plugin manager: [sheldon](https://github.com/rossmacarthur/sheldon)

```sh
brew install sheldon
```

Back up existing `.zshrc` if exists:

```sh
mv ~/.zshrc ~/.zshrc.backup
```

soft link dotfiles:

```sh
stow sheldon
```

> **Adding a new `~/.zsh/*.zsh` fragment?** Run `sheldon lock` then `exec zsh`.
> Sheldon caches the `*.zsh` glob in its lockfile and won't pick up new files otherwise.

### yabai

install yabai

```sh
brew install yabai
```

install config

```sh
stoe yabai
```

run services

```sh
yabai --start-service
```

### skhd

hotkey daemon

```sh
brew install skhd
```

install config

```sh
stow skhd
```

run service

```sh
skhd --start-services
```

### skeychybar

top bar

```sh
brew install sketchybar
```

install config

```sh
stow sketchybar
```

run service

```sh
brew services start sketchybar
```

### borders

[JankyBorders](https://github.com/FelixKratz/JankyBorders)

```sh
brew install borders
```

install config

```sh
stow borders
```

run the serce

```sh
brew services start borders
```

### vim

the editor. Install config:

```sh
stow vim
```

Run `:PlugInstall` in vim

### herdr

install config

```sh
stow herdr
```

> Only `config.toml` is tracked. `herdr-*.log`, `*.sock`, `session.json`, and `.plugins.lock` are
> runtime state left in `~/.config/herdr` untouched by stow.

### executables

to `~/.bin`

```sh
stow bin
```