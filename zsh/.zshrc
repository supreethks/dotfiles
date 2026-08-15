# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# This overrides venv python
# alias python="python3"
# alias pip="pip3"


# Android sdk variables
ANDROID_SDK_ROOT="/Users/supreethks/Library/Android/sdk"
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Enable command auto-completion
autoload -Uz compinit
compinit

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"

# Enable plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Load zsh-autosuggestions
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Load zsh-syntax-highlighting
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# Created by `pipx` on 2025-06-05 04:07:12
export PATH="$PATH:/Users/supreethks/.local/bin"
#alias python3="/opt/homebrew/bin/python3"
#alias python="/opt/homebrew/bin/python3"
eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$HOME/.local/bin:$PATH"

# Kitty shell integration (enable richer features in kitty)
# Only set install dir when running inside Kitty
if [[ -n "$KITTY_PID" && -z "$KITTY_INSTALLATION_DIR" && -d "/Applications/kitty.app/Contents/Resources/kitty" ]]; then
  export KITTY_INSTALLATION_DIR="/Applications/kitty.app/Contents/Resources/kitty"
fi
if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
  export KITTY_SHELL_INTEGRATION="enabled"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

# Starship 
eval "$(starship init zsh)"
# Load local / machine-specific secrets and overrides if present
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Added by Antigravity
export PATH="/Users/supreethks/.antigravity/antigravity/bin:$PATH"
export PATH=$PATH:$HOME/.maestro/bin

# Added by Antigravity
export PATH="/Users/supreethks/.antigravity/antigravity/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="/Users/supreethks/.local/bin:$PATH"

# Added by Antigravity
export PATH="/Users/supreethks/.antigravity/antigravity/bin:$PATH"

# Obsidian daily note helper (supports DDMMYY, DD-MM-YY, YYYY-MM-DD, or today)
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
