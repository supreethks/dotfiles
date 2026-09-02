# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Zsh Configuration (.zshrc)                                          ║
# ║  Optimized for Ghostty + Tmux + Starship + Modern CLI tools          ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Disable automatic update prompting (let it update in background)
zstyle ':omz:update' mode auto

# Oh My Zsh plugins (fzf-tab before widget wrappers)
plugins=(
  git
  fzf-tab
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# History: large shared file as a fallback even when Atuin is the search UI
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
HISTORY_IGNORE='(ls|ls *|cd|cd *|pwd|exit|clear|history|history *)'
setopt HIST_REDUCE_BLANKS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY

autoload -Uz compinit && compinit

# fzf-tab after compinit, then widget wrappers
[[ -f ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab/fzf-tab.plugin.zsh ]] && source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab/fzf-tab.plugin.zsh
[[ -f ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Ctrl+F: accept autosuggestion one word at a time (Ctrl+E / → still accept full)
bindkey '^F' forward-word

# ── Environment & Path ───────────────────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/.maestro/bin:$PATH"

# Android SDK
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# ── Modern CLI Aliases & Replacements ────────────────────────────────────

# eza (modern ls replacement)
if (( $+commands[eza] )); then
  alias ls="eza --icons=always --group-directories-first"
  alias la="eza -a --icons=always --group-directories-first"
  alias ll="eza -l --icons=always --group-directories-first --git"
  alias lla="eza -la --icons=always --group-directories-first --git"
  alias lt="eza -l --sort=modified --reverse --group-directories-last --no-permissions --no-user --icons=always"
  alias tree="eza --tree --icons=always --level=3"
fi

# bat (modern cat replacement with syntax highlighting)
if (( $+commands[bat] )); then
  alias cat="bat --style=plain"
  alias preview="bat --color=always"
  export BAT_THEME="ansi" # Matches terminal theme naturally
fi

# fzf (fuzzy finder options)
if (( $+commands[fzf] )); then
  # Exclude system/cache directories from search
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude Library --exclude Applications --exclude System --exclude '.cache' --exclude '.npm' --exclude '.cargo' --exclude '.gemini' --exclude '.rustup' --exclude '.local' --exclude '.cocoapods' --exclude '.android' --exclude '.cursor' --exclude '.gradle'"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude Library --exclude Applications --exclude System --exclude '.cache' --exclude '.npm' --exclude '.cargo' --exclude '.gemini' --exclude '.rustup' --exclude '.local' --exclude '.cocoapods' --exclude '.android' --exclude '.cursor' --exclude '.gradle'"

  # Larger preview window (60% width) and scroll/wrap options
  export FZF_DEFAULT_OPTS="--height 85% --layout=reverse --border --color=16 --preview-window=right:60%:wrap"

  # Rich preview command for files, photos (using chafa), and PDFs (using pdftotext or exiftool)
  export FZF_CTRL_T_OPTS="--preview '
    mime=\$(file --mime-type -b {})
    if [[ \$mime =~ ^image/ ]]; then
      chafa -s 70x35 {} 2>/dev/null || exiftool {}
    elif [[ \$mime == \"application/pdf\" ]]; then
      pdftotext -l 5 -layout {} - 2>/dev/null || exiftool {}
    elif [[ -d {} ]]; then
      eza --tree --level=2 --icons=always {}
    else
      bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {}
    fi
  '"

  # Find & Open Aliases (bypasses Zellij Ctrl+T conflict)
  alias fo="open \$(fzf)"
  alias fc="cursor \$(fzf)"
  alias fv="nvim \$(fzf)"

  # File/dir widgets. History search is rebound by Atuin when it is installed.
  source <(fzf --zsh)
fi

# Atuin (SQLite history + fuzzy Ctrl+R). Load after fzf so it owns Ctrl+R.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-ai)"
fi

# zoxide (smarter directory jumping)
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# fastfetch (system info fetcher)
if (( $+commands[fastfetch] )); then
  alias fetch="fastfetch"
fi

# Kitty shell integration (only if running in Kitty)
if [[ -n "$KITTY_PID" && -d "/Applications/kitty.app/Contents/Resources/kitty" ]]; then
  export KITTY_INSTALLATION_DIR="/Applications/kitty.app/Contents/Resources/kitty"
  export KITTY_SHELL_INTEGRATION="enabled"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

# ── Prompts & Shell Utils ───────────────────────────────────────────────
eval "$(starship init zsh)"

# AIChat shell helper (Cmd+E in Ghostty → Alt+E sequence). Uses `cursor-agent`.
# macOS default is ~/Library/Application Support/aichat; pin the XDG path from dotfiles.
export AICHAT_CONFIG_DIR="$HOME/.config/aichat"
AICHAT_PROXY_PORT=18741
AICHAT_PROXY="$HOME/.config/aichat/cursor-agent-openai-proxy.py"

_aichat_ensure_proxy() {
  if ! command -v cursor-agent >/dev/null 2>&1; then
    echo "cursor-agent not found; install Cursor Agent CLI and sign in" >&2
    return 1
  fi
  if [[ ! -f "$AICHAT_PROXY" ]]; then
    echo "missing $AICHAT_PROXY" >&2
    return 1
  fi
  if nc -z 127.0.0.1 "$AICHAT_PROXY_PORT" >/dev/null 2>&1; then
    return 0
  fi
  nohup python3 "$AICHAT_PROXY" >/dev/null 2>&1 &
  disown
  local i
  for i in {1..40}; do
    nc -z 127.0.0.1 "$AICHAT_PROXY_PORT" >/dev/null 2>&1 && return 0
    sleep 0.05
  done
  echo "failed to start aichat cursor-agent proxy on port $AICHAT_PROXY_PORT" >&2
  return 1
}

function '??' {
  _aichat_ensure_proxy || return 1
  if (( $# == 0 )); then
    aichat
  else
    aichat -e "$*"
  fi
}

_aichat_zsh() {
  if [[ -z "$BUFFER" ]]; then
    return
  fi
  if ! _aichat_ensure_proxy; then
    return 1
  fi
  local _old=$BUFFER
  local _err
  BUFFER+="⌛"
  zle -I && zle redisplay
  BUFFER=$(aichat -e "$_old" 2>/tmp/aichat-cursor-agent.err)
  if [[ $? -ne 0 || -z "$BUFFER" ]]; then
    _err=$(tail -n 3 /tmp/aichat-cursor-agent.err 2>/dev/null)
    BUFFER="$_old"
    zle -M "${_err:-aichat/cursor-agent failed}"
  fi
  zle end-of-line
}
zle -N _aichat_zsh
bindkey '\ee' _aichat_zsh

# Load local / machine-specific secrets and overrides if present
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# ── Smart CD & Directory Navigation ───────────────────────────────────────
cd() {
  if (( $# == 0 )); then
    builtin cd ~
  elif [[ "$1" == "-" ]]; then
    builtin cd -
  elif builtin cd "$@" 2>/dev/null; then
    return 0
  elif [[ $# -eq 1 && -d "$HOME/development/project-$1" ]]; then
    builtin cd "$HOME/development/project-$1"
  elif [[ $# -eq 1 && -d "$HOME/development/$1" ]]; then
    builtin cd "$HOME/development/$1"
  elif (( $+commands[zoxide] )) && zoxide query "$@" &>/dev/null; then
    builtin cd "$(zoxide query "$@")"
  else
    builtin cd "$@"
  fi
}

# Automatically create named directories (~name) and aliases for development folders
for dir in ~/development/*/(N); do
  if [[ -d "$dir" ]]; then
    dir_name=$(basename "$dir")
    clean_name="${dir_name#project-}"
    hash -d "$clean_name"="$dir"
    hash -d "$dir_name"="$dir"
    if (( $+commands[$clean_name] )); then
      continue
    fi
    alias "$clean_name"="cd $dir"
  fi
done


# Obsidian daily note helper
obdaily() {
  local input="$1"
  local target_date

  if [ -z "$input" ]; then
    target_date=$(date +"%Y-%m-%d")
  else
    target_date=$(python3 -c "
import sys, re
from datetime import datetime

raw = sys.argv[1].strip()
clean = re.sub(r'[-/.]', '', raw)

if len(clean) == 6 and clean.isdigit():
    print(datetime.strptime(clean, '%d%m%y').strftime('%Y-%m-%d'))
elif len(clean) == 8 and clean.isdigit() and int(clean[2:4]) <= 12 and int(clean[:2]) <= 31:
    print(datetime.strptime(clean, '%d%m%Y').strftime('%Y-%m-%d'))
elif re.match(r'^\d{4}-\d{2}-\d{2}$', raw):
    print(raw)
else:
    print(raw)
" "$input")
  fi

  obsidian open "journal/${target_date}" -v main-vault
}

# Ghostty quick terminal (Cmd+`) → persisted Herdr "quake" session for quick agent help
if [[ "$GHOSTTY_QUICK_TERMINAL" == "1" && -z "$HERDR_SESSION" ]] && command -v herdr >/dev/null 2>&1; then
  exec herdr --session quake
fi

# ── App Aliases ─────────────────────────────────────────────────────────
alias zj="zellij"
alias h="herdr"

# Rename the current Herdr tab: hrr <new-name>
hrr() {
  if [[ "${HERDR_ENV:-}" != 1 || -z "${HERDR_TAB_ID:-}" ]]; then
    echo "hrr: not inside a herdr tab" >&2
    return 1
  fi
  if [[ $# -lt 1 ]]; then
    echo "usage: hrr <new-name>" >&2
    return 1
  fi
  herdr tab rename "$HERDR_TAB_ID" "$*"
}

unalias trr 2>/dev/null
trr() {
  if ! "$HOME/media-server/scripts/nord-vpn-connected.sh" >/dev/null 2>&1; then
    echo "trr: refused — NordVPN is not connected." >&2
    return 1
  fi
  case "$1" in
    start)
      shift
      transmission-remote -t all -s "$@"
      ;;
    stop)
      shift
      transmission-remote -t all -S "$@"
      ;;
    *)
      transmission-remote "$@"
      ;;
  esac
}

# Jellyfin-safe torrent pick: 1080p DSNP WEB-DL H.264 DDP, no HEVC/REMUX/micro-encodes
tordl-jellyfin() {
  local title="$*"
  if [[ -z "$title" ]]; then
    echo "Usage: tordl-jellyfin Movie Title 2024" >&2
    return 1
  fi
  if ! command -v tordl >/dev/null 2>&1; then
    echo "tordl-jellyfin: tordl not found in PATH" >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "tordl-jellyfin: jq not found in PATH" >&2
    return 1
  fi
  local json match name seeds leeches size magnet source reply
  echo "Searching for Jellyfin-safe release: $title"
  if ! json=$(tordl -a "$title" 2>/dev/null); then
    echo "tordl-jellyfin: search failed" >&2
    return 1
  fi
  if ! echo "$json" | jq -e '.result' >/dev/null 2>&1; then
    echo "tordl-jellyfin: invalid response from tordl" >&2
    return 1
  fi
  match=$(echo "$json" | jq -c '
    .result
    | map(select(
        (.name | test("1080p"; "i"))
        and (.name | test("WEB-DL"; "i"))
        and (.name | test("DSNP"; "i"))
        and (.name | test("H[ .]?264|x264"; "i"))
        and (.name | test("HEVC|x265|H[ .]?265"; "i") | not)
        and (.name | test("DDP"; "i"))
        and (.name | test("BrRip|YIFY|REMUX|ita|720p|2160p|BluRay"; "i") | not)
      ))
    | sort_by(-.seeds)
    | .[0] // null
  ')
  if [[ "$match" == "null" || -z "$match" ]]; then
    echo "No Jellyfin-safe match for: $title"
    return 1
  fi
  name=$(echo "$match" | jq -r '.name')
  seeds=$(echo "$match" | jq -r '.seeds')
  leeches=$(echo "$match" | jq -r '.leeches')
  size=$(echo "$match" | jq -r '.size')
  source=$(echo "$match" | jq -r '.origins | join(", ")')
  magnet=$(echo "$match" | jq -r '.magnet_url')
  echo ""
  echo "Best match:"
  echo "  Title:    $name"
  echo "  Source:   $source"
  echo "  Seeds:    $seeds"
  echo "  Leechers: $leeches"
  echo "  Size:     $size"
  echo ""
  read -r "reply?Add to Transmission in $(pwd)? [y/N] "
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    return 0
  fi
  trr -w "$(pwd)" -a "$magnet"
}


# clipshot Ghostty integration
export CLIPSHOT_TEMPLATE="See screenshot : {link} "
[[ -f "$HOME/development/clipshot/zsh/clipshot.zsh" ]] && source "$HOME/development/clipshot/zsh/clipshot.zsh"

# Chrome with remote debugging port for local AI browser automation
alias chrome-debug='nohup "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir="$HOME/.config/chrome-automation" >/dev/null 2>&1 &'

# opencode
export PATH=/Users/supreethks/.opencode/bin:$PATH
