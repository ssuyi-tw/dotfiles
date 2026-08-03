# Essentials for this dotfiles setup: shell, terminal, system-level config
# brew bundle --file=~/dotfiles/brew/00-base.Brewfile

tap "asmvik/formulae", trusted: { formulae: ["skhd", "yabai"] }
tap "felixkratz/formulae", "https://github.com/FelixKratz/homebrew-formulae"

# --- System: window management (see yabai/, skhd/, sketchybar/, borders/)

# Tiling window manager
brew "asmvik/formulae/yabai", trusted: true
# Hotkey daemon
brew "asmvik/formulae/skhd"
# Status bar
brew "felixkratz/formulae/sketchybar", trusted: true
# Window borders (JankyBorders)
brew "felixkratz/formulae/borders", trusted: true

# Fonts required by sketchybar / terminal
cask "font-hack-nerd-font"
cask "font-sketchybar-app-font"
cask "font-fontawesome"
cask "sf-symbols"

# --- Terminal (see ghostty/)

cask "ghostty"

# --- Shell + CLI

brew "bat"
brew "btop"

brew "fastfetch"
brew "fd"
brew "fzf"
brew "gh"

# Syntax-highlighting pager for git and diff output
brew "git-delta"
brew "git-filter-repo"

# GPG
brew "gnupg"
brew "pinentry-mac"

brew "jq"
brew "yq"
brew "lsd"
brew "macmon"
brew "mtr"
brew "ripgrep"

# Shell plugin manager (loads zsh plugins, see sheldon/)
brew "sheldon"

# Prompt
brew "starship"

# Symlink farm manager — how this dotfiles repo is applied
brew "stow"

brew "tree"

# Directory jumper
brew "zoxide"
