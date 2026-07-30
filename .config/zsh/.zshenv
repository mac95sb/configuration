# Keep this file minimal: zsh reads it for every invocation.
export ZDOTDIR="$HOME/.config/zsh"

# Silence macOS Terminal session restoration output/commands.
export SHELL_SESSIONS_DISABLE=1

if [ -f "$ZDOTDIR/.zshenv.local" ]; then
  . "$ZDOTDIR/.zshenv.local"
fi
