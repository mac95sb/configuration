# Periodic auto-update on Zsh startup.
zstyle ':z4h:' auto-update      'yes'
zstyle ':z4h:' auto-update-days '28'

# Keyboard type.
zstyle ':z4h:bindkey' keyboard 'mac'

# Mark up shell output with semantic information.
zstyle ':z4h:' term-shell-integration 'yes'

# Keep the prompt at the top after shell startup and Ctrl+L.
zstyle ':z4h:' prompt-at-bottom 'no'

# Right-arrow key accepts the whole command autosuggestion.
zstyle ':z4h:autosuggestions' forward-char 'accept'

# Use the Powerlevel10k config
typeset -g POWERLEVEL9K_CONFIG_FILE="${ZDOTDIR:-$HOME}/.p10k.zsh"

# Bootstrap zsh4humans when it hasn't already been loaded from ~/.zshenv.
if (( ! $+functions[z4h] )); then
  Z4H_URL="https://raw.githubusercontent.com/romkatv/zsh4humans/v5"
  : "${Z4H:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4humans/v5}"

  if [[ ! -e "$Z4H/z4h.zsh" ]]; then
    mkdir -p -- "$Z4H" || return
    print -Pu2 '%F{yellow}z4h%f: fetching %Uz4h.zsh%u'
    curl -fsSL -- "$Z4H_URL/z4h.zsh" >"$Z4H/z4h.zsh.$$" || return
    mv -- "$Z4H/z4h.zsh.$$" "$Z4H/z4h.zsh" || return
  fi

  source "$Z4H/z4h.zsh" || return
fi

# Install or update core components and initialize Zsh.
z4h init || return

# PATH.
path=("$HOME/.local/bin" $path)
typeset -U path PATH

# Options.
setopt HIST_IGNORE_ALL_DUPS INTERACTIVE_COMMENTS

kp() {
  kill $(lsof -tiTCP:"$1" -sTCP:LISTEN)
}

eval "$(~/.local/bin/mise activate zsh)"
