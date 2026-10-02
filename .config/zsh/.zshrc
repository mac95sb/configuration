zstyle ':z4h:' auto-update      'yes'
zstyle ':z4h:' auto-update-days '28'
zstyle ':z4h:bindkey' keyboard 'mac'
zstyle ':z4h:' term-shell-integration 'yes'
zstyle ':z4h:' prompt-at-bottom 'no'
zstyle ':z4h:autosuggestions' forward-char 'accept'
typeset -g POWERLEVEL9K_CONFIG_FILE="${ZDOTDIR:-$HOME}/.p10k.zsh"

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

z4h init || return

path=("$HOME/.local/bin" $path)
typeset -U path PATH

setopt HIST_IGNORE_ALL_DUPS INTERACTIVE_COMMENTS

kp() {
  kill $(lsof -tiTCP:"$1" -sTCP:LISTEN)
}

eval "$(~/.local/bin/mise activate zsh)"
