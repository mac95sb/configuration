path=("$HOME/.local/bin" $path)
typeset -U path

command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

autoload -Uz compinit
if [[ -f ${ZDOTDIR:-$HOME}/.zcompdump ]] && [[ -z ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit -C
else
    compinit
fi

setopt AUTO_CD HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

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
