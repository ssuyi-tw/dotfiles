export PATH="$HOME/.local/bin:$PATH"
eval "$(sheldon source)"

if command -v pyenv >/dev/null; then
  eval "$(pyenv init - zsh)"
fi
