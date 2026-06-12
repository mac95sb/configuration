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
  git rev-parse --is-inside-work-tree &>/dev/null || return
  local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
  local s=""
  git diff --quiet 2>/dev/null || s="*"
  git diff --cached --quiet 2>/dev/null || s+="+"
  echo " $branch$s"
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

ghi() {
  local repos=("$@")
  [[ ${#repos} -eq 0 ]] && { print -u2 "usage: ghi user/repo [user/repo ...]"; return 1 }
  for repo in $repos; do
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
    local tmp=$(mktemp -d)
    trap "rm -rf $tmp" EXIT
    local dl="$tmp/dl"
    [[ $url == *.pkg ]] && dl="$tmp/dl.pkg"
    curl -fSL --progress-bar -o "$dl" "$url" || continue
    local src="$tmp/out"
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
    # Descend through a single wrapper dir (e.g. nvim-macos-arm64/). Keep this
    # as an array: glob qualifiers do not reliably expand in the old [[ -d ... ]]
    # test, which made archives with bin/lib/share fall through to "copy binary".
    local entries=("$src"/*(N))
    [[ ${#entries} -eq 1 && -d ${entries[1]} ]] && src="${entries[1]}"
    mkdir -p ~/.local/bin
    if [[ -d "$src/bin" || -d "$src/lib" || -d "$src/share" ]]; then
      # Full tree: rsync merges into ~/.local/ without clobbering other tools.
      # Trailing slash on src is load-bearing — it means "merge contents", not
      # "copy the directory itself". This ensures share/ and lib/ land correctly,
      # which is required for tools like Neovim that need runtime files alongside
      # their binary.
      rsync -a "$src"/ ~/.local/
      chmod +x ~/.local/bin/*(N)
      print "✓ merged ${repo:t} → ~/.local/"
    else
      find "$src" -type f | xargs file | grep 'Mach-O.*executable' | cut -d: -f1 \
        | while read -r f; do
            cp "$f" ~/.local/bin/
            chmod +x ~/.local/bin/${f:t}
            print "✓ ~/.local/bin/${f:t}"
          done
    fi
  done
}
