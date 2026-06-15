typeset -U path cdpath fpath manpath
for profile in ${(z)NIX_PROFILES}; do
  fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
done

HELPDIR="/nix/store/5qjgn064c7krl34ncilmyh45x2wvcn2m-zsh-5.9.1/share/zsh/$ZSH_VERSION/help"

EDITOR="nvim"
autoload -U compinit && compinit
source /nix/store/7lxzhigfwqvbsqls0471qim3h8iwih40-zsh-autosuggestions-0.7.1/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history)


# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
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

autoload -Uz -- _build_prompt _git_info hr kp tdl theme
if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
  source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
fi

alias -- dr='sudo darwin-rebuild switch --flake ~/Developer/configuration#mac'
precmd_functions+=(_build_prompt)

source /nix/store/b4xhd710lddjg6ldf2ycbaf5lsgqgika-zsh-syntax-highlighting-0.8.0/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)


