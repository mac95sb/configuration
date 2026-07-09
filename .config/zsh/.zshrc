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

# Don't recursively traverse directories when TAB-completing files.
zstyle ':z4h:fzf-complete' recurse-dirs 'no'

# Disable automatic z4h SSH teleportation by default.
zstyle ':z4h:ssh:*' enable 'no'

# Use the tracked Powerlevel10k config symlinked into ZDOTDIR.
typeset -g POWERLEVEL9K_CONFIG_FILE="${ZDOTDIR:-$HOME}/.p10k.zsh"

# Bootstrap zsh4humans when it hasn't already been loaded from ~/.zshenv.
if (( ! $+functions[z4h] )); then
  Z4H_URL="https://raw.githubusercontent.com/romkatv/zsh4humans/v5"
  : "${Z4H:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4humans/v5}"

  if [[ ! -e "$Z4H/z4h.zsh" ]]; then
    mkdir -p -- "$Z4H" || return
    print -Pu2 '%F{yellow}z4h%f: fetching %Uz4h.zsh%u'
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL -- "$Z4H_URL/z4h.zsh" >"$Z4H/z4h.zsh.$$" || return
    elif command -v wget >/dev/null 2>&1; then
      wget -O- -- "$Z4H_URL/z4h.zsh" >"$Z4H/z4h.zsh.$$" || return
    else
      print -Pu2 '%F{yellow}z4h%f: please install %F{green}curl%f or %F{green}wget%f'
      return 1
    fi
    mv -- "$Z4H/z4h.zsh.$$" "$Z4H/z4h.zsh" || return
  fi

  source "$Z4H/z4h.zsh" || return
fi

# Install or update core components and initialize Zsh.
z4h init || return

# PATH.
path=("$HOME/.local/bin" "$HOME/bin" $path)
typeset -U path PATH

# History.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt AUTO_CD HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# Shell options.
setopt GLOB_DOTS NO_AUTO_MENU
