eval "$(/opt/homebrew/bin/mise activate zsh)"

autoload -Uz compinit && compinit

setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_EXPIRE_DUPS_FIRST SHARE_HISTORY

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

path+=("$HOME/.local/bin")
typeset -U path

plugins=(
  zsh-autosuggestions/zsh-autosuggestions.zsh
  zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
)

for plugin in "${plugins[@]}"; do
  [[ -r "/opt/homebrew/share/$plugin" ]] && source "/opt/homebrew/share/$plugin"
done

PROMPT='
%F{#6C91BF}%~%f
%(?.%F{#a6dbff}.%F{#ff9e64})λ%f '

kp() {
  if [[ -z "$1" ]]; then
    print -u2 "kp: usage: kp <port>"
    return 1
  fi
  local pids
  pids=$(lsof -ti :"$1") || { print -u2 "kp: no process on port $1"; return 1; }
  print "$pids" | xargs kill -9
}
