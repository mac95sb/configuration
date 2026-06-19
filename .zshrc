eval "$(/opt/homebrew/bin/brew shellenv)"

autoload -Uz compinit && compinit

setopt AUTO_CD
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt SHARE_HISTORY

HISTSIZE=50000
SAVEHIST=50000
HISTFILE="$HOME/.zsh_history"

path+=("$HOME/.local/bin")
typeset -U path

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

_build_prompt() {
  local e=$?
  local sym="%F{#a6dbff}"
  (( e != 0 )) && sym="%F{#ff9e64}"
  PROMPT="
%F{#6C91BF}%~%F{#767676}%f
${sym}λ%f "
}

precmd_functions+=(_build_prompt)

kp() {
  if [[ -z "$1" ]]; then
    print -u2 "kp: usage: kp <port>"
    return 1
  fi
  local pids
  pids=$(lsof -ti :"$1") || { print -u2 "kp: no process on port $1"; return 1; }
  print "$pids" | xargs kill -9
}
