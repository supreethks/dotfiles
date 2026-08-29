# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Zsh Configuration (.zshrc)                                          ║
# ║  Optimized for Ghostty + Tmux + Starship + Modern CLI tools          ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Disable automatic update prompting (let it update in background)
zstyle ':omz:update' mode auto

# Oh My Zsh plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Load zsh-autosuggestions & zsh-syntax-highlighting if custom paths exist
[[ -f ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ── Environment & Path ───────────────────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH="$HOME/.local/bin:$PATH"
export PATH="/Users/supreethks/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/.maestro/bin:$PATH"

# Android SDK
export ANDROID_SDK_ROOT="/Users/supreethks/Library/Android/sdk"
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

# Enable command auto-completion
autoload -Uz compinit && compinit

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

# ── App Aliases ─────────────────────────────────────────────────────────
alias zj="zellij"
alias h="herdr"


# clipshot Ghostty integration
export CLIPSHOT_TEMPLATE="See screenshot : {link} "
[[ -f "$HOME/development/clipshot/zsh/clipshot.zsh" ]] && source "$HOME/development/clipshot/zsh/clipshot.zsh"
