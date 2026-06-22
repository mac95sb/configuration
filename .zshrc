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

[[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

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

bc() {
  local file
  local found=0

  for file in Brewfile(N) MacsBrewfile(N) */Brewfile(N) */MacsBrewfile(N); do
    [[ -f "$file" ]] || continue
    found=1
    brew bundle check --file="$file" || brew bundle install --file="$file" || return
  done

  (( found )) || { print -u2 "bc: no Brewfile found"; return 1; }
}

# Hermes Agent — ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"
