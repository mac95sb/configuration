

autoload -U compinit && compinit
ZSH_AUTOSUGGEST_STRATEGY=(history)


# History options should be set in .zshrc and after oh-my-zsh sourcing.
HISTSIZE="50000"
SAVEHIST="50000"

HISTFILE="/Users/mac/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

# Set shell options
set_opts=(
  HIST_FCNTL_LOCK HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_SPACE
  SHARE_HISTORY autocd NO_APPEND_HISTORY NO_EXTENDED_HISTORY
  NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS
)
for opt in "${set_opts[@]}"; do
  setopt "$opt"
done
unset opt set_opts

autoload -Uz -- _build_prompt _git_info dr hr kp tdl theme
if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
  source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
fi

precmd_functions+=(_build_prompt)

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)


