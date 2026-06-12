# General Options
setopt AUTO_CD
PATH="$HOME/.local/bin:$PATH"

# History Management
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_EXPIRE_DUPS_FIRST SHARE_HISTORY

# Custom Prompt
_git_info() {
  local out
  out=$(git status --porcelain=v1 -b 2>/dev/null) || return
  local branch=${${out%%$'\n'*}#'## '}
  branch=${branch%%...*}
  local s=""
  [[ $out == *$'\n'?[!\ ?]* ]] && s="*"
  [[ $out == *$'\n'[!\ ?]* ]] && s+="+"
  print " $branch$s"
}

_build_prompt() {
  local e=$?
  local sym="%F{#a6dbff}"
  (( e != 0 )) && sym="%F{#ff9e64}"
  PROMPT="
%F{#6C91BF}%~%F{#767676}$(_git_info)%f
${sym}λ%f "
}

precmd_functions+=(_build_prompt)

# Custom Functions
kp() {
  lsof -ti :"$1" | xargs kill -9
}

tdl() {
  emulate -L zsh

  if ! command -v tmux >/dev/null 2>&1; then
    print -u2 "tdl: tmux is not installed"
    return 1
  fi

  local editor="${EDITOR:-nvim}"
  local window_name="${PWD:t}"
  [[ -z $window_name ]] && window_name="tdl"

  local target session
  if [[ -n $TMUX ]]; then
    target=$(tmux display-message -p '#{session_name}:#{window_index}')
  else
    session="tdl-${window_name//[^A-Za-z0-9_.-]/-}"
    if tmux has-session -t "$session" 2>/dev/null; then
      tmux attach-session -t "$session"
      return
    fi
    target=$(tmux new-session -d -P -F '#{session_name}:#{window_index}' -s "$session" -n "$window_name" -c "$PWD")
  fi

  local editor_pane agent_pane
  editor_pane=$(tmux display-message -p -t "$target" '#{pane_id}')
  tmux send-keys -t "$editor_pane" -- "$editor" C-m

  tmux split-window -v -p 18 -t "$editor_pane" -c "$PWD" >/dev/null
  agent_pane=$(tmux split-window -h -p 30 -t "$editor_pane" -c "$PWD" -P -F '#{pane_id}')

  local pane="$agent_pane"
  for agent in "${@:1:$(( $# > 0 ? $# - 1 : 0 ))}"; do
    tmux send-keys -t "$pane" -- "$agent" C-m
    pane=$(tmux split-window -v -t "$pane" -c "$PWD" -P -F '#{pane_id}')
  done
  (( $# )) && tmux send-keys -t "$pane" -- "${@[-1]}" C-m

  tmux select-pane -t "$editor_pane"

  if [[ -z $TMUX ]]; then
    tmux attach-session -t "$session"
  fi
}

# Dev Container
alias dev='container machine run'
alias dev-stop='container machine stop'

dev_build() {
  emulate -L zsh
  local image="${DEV_IMAGE:-local/dev-void:latest}"
  container build -t "$image" -f "$HOME/.config/Containerfile" "$HOME/.config"
}

dev_recreate() {
  emulate -L zsh
  local image="${DEV_IMAGE:-local/dev-void:latest}"
  dev_build
  if container machine inspect dev >/dev/null 2>&1; then
    print -u2 "dev_recreate: this will delete and recreate the dev machine."
    printf "Continue? [y/N] "
    local answer
    read -r answer
    [[ $answer == [Yy]* ]] || return 1
    container machine delete dev
  fi
  container machine create --name dev --set-default "$image"
}

ghi() {
  [[ $# -eq 0 ]] && { print -u2 "usage: ghi user/repo [user/repo ...]"; return 1 }
  local tmp=$(mktemp -d)
  trap "rm -rf $tmp" EXIT
  for repo in "$@"; do
    [[ $repo != */* ]] && { print -u2 "ghi: skipping '$repo' (not user/repo format)"; continue }
    local assets
    assets=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
      | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    print(a['browser_download_url'])
" \
      | grep -v -Ei '\.(sha256|sha512|sig|asc|sbom|txt)$')
    local url
    url=$(echo "$assets" \
      | grep -Ei 'darwin|macos|apple' \
      | grep -Ei 'arm64|aarch64' \
      | head -n1)
    [[ -z $url ]] && url=$(echo "$assets" \
      | grep -Ei 'darwin|macos|apple|installer|signed' \
      | grep -Ei '\.pkg$' \
      | head -n1)
    if [[ -z $url ]]; then
      print -u2 "ghi: no arm64 macOS asset found for ${repo}"
      continue
    fi
    print "→ ${url:t}"
    local rtmp="$tmp/${repo//\//_}"
    mkdir -p "$rtmp"
    local dl="$rtmp/dl"
    [[ $url == *.pkg ]] && dl="$rtmp/dl.pkg"
    curl -fSL --progress-bar -o "$dl" "$url" || continue
    local src="$rtmp/out"
    mkdir -p "$src"
    case $url in
      *.tar.*|*.tgz|*.txz) tar xf "$dl" -C "$src" ;;
      *.zip)               unzip -q "$dl" -d "$src" ;;
      *.gz)                gunzip -c "$dl" > "$src/${${url:t}%.gz}" ;;
      *.pkg)
        print "→ installing .pkg (requires sudo)"
        sudo installer -pkg "$dl" -target / || continue
        print "✓ ${repo:t} installed via pkg"
        continue
        ;;
      *) cp "$dl" "$src/${url:t}" ;;
    esac
    local entries=("$src"/*(N))
    [[ ${#entries} -eq 1 && -d ${entries[1]} ]] && src="${entries[1]}"
    mkdir -p ~/.local/bin
    if [[ -d "$src/bin" || -d "$src/lib" || -d "$src/share" ]]; then
      rsync -a "$src"/ ~/.local/
      chmod +x ~/.local/bin/*(N)
      print "✓ merged ${repo:t} → ~/.local/"
    else
      for f in "$src"/**/*(N.); do
        file "$f" | grep -q 'Mach-O.*executable' || continue
        cp "$f" ~/.local/bin/
        chmod +x ~/.local/bin/${f:t}
        print "✓ ~/.local/bin/${f:t}"
      done
    fi
  done
}

nvim_deps() {
  emulate -L zsh

  if ! command -v lua-language-server >/dev/null 2>&1; then
    ghi LuaLS/lua-language-server
  fi

  print "nvim_deps: Node-based language servers are provided by the dev machine image"

  local required_missing=()
  for cmd in sourcekit-lsp lua-language-server; do
    command -v "$cmd" >/dev/null 2>&1 || required_missing+=("$cmd")
  done

  if (( ${#required_missing} )); then
    print -u2 "nvim_deps: still missing: ${required_missing[*]}"
    return 1
  fi

  print "✓ Neovim external dependencies installed"
}
