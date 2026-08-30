#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This requirements installer currently supports macOS only." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Homebrew is required but was not found.
Install it from https://brew.sh, then run this script again.
EOF
  exit 1
fi

echo "==> Installing Homebrew requirements"
brew bundle --file="$DOTFILES_DIR/Brewfile"

install_remote_installer() {
  local command_name="$1"
  local installer_url="$2"
  local interpreter="${3:-bash}"
  local installer_file

  if command -v "$command_name" >/dev/null 2>&1; then
    echo "  [SKIP] $command_name is already installed"
    return
  fi

  installer_file="$(mktemp -t "${command_name}-installer")"
  echo "  [INSTALL] $command_name"

  if ! curl --fail --silent --show-error --location "$installer_url" --output "$installer_file"; then
    rm -f "$installer_file"
    return 1
  fi

  if ! "$interpreter" "$installer_file"; then
    rm -f "$installer_file"
    return 1
  fi

  rm -f "$installer_file"
}

echo "==> Installing coding-agent CLIs"
install_remote_installer "herdr" "https://herdr.dev/install.sh" "sh"
install_remote_installer "codex" "https://chatgpt.com/codex/install.sh" "sh"
install_remote_installer "claude" "https://claude.ai/install.sh" "bash"
install_remote_installer "agy" "https://antigravity.google/cli/install.sh"
install_remote_installer "cursor-agent" "https://cursor.com/install"

if command -v herdr >/dev/null 2>&1; then
  echo "==> Installing Herdr plugins"
  installed_plugins="$(herdr plugin list 2>/dev/null || true)"
  install_herdr_plugin() {
    local plugin_id="$1"
    local plugin_repo="$2"
    if echo "$installed_plugins" | grep -q "$plugin_id"; then
      echo "  [SKIP] Herdr plugin $plugin_id is already installed"
    else
      echo "  [INSTALL] Herdr plugin $plugin_id from $plugin_repo"
      herdr plugin install "$plugin_repo" -y || echo "  [WARN] Failed to install Herdr plugin $plugin_repo"
    fi
  }
  install_herdr_plugin "herdr-navigator" "thanhdat77/herdr-navigator"
  install_herdr_plugin "herdr-ai-tracker" "supreethks/herdr-ai-tracker"
  install_herdr_plugin "chmarax.herdr-nvim" "ChmaraX/herdr-nvim"
  install_herdr_plugin "annotate" "plannotator/herdr-annotate"

  echo "==> Installing Herdr agent integrations"
  for agent in claude codex antigravity-cli cursor grok pi; do
    herdr integration install "$agent" 2>/dev/null || true
  done
fi




install_git_checkout() {
  local repo_url="$1"
  local destination="$2"

  if [[ -d "$destination/.git" ]]; then
    echo "  [SKIP] $destination already exists"
    return
  fi

  if [[ -e "$destination" ]]; then
    echo "  [WARN] $destination exists but is not a Git checkout; leaving it unchanged"
    return
  fi

  git clone --depth=1 "$repo_url" "$destination"
}

echo "==> Installing Oh My Zsh and shell plugins"
install_git_checkout \
  "https://github.com/ohmyzsh/ohmyzsh.git" \
  "$HOME/.oh-my-zsh"

install_git_checkout \
  "https://github.com/zsh-users/zsh-autosuggestions.git" \
  "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

install_git_checkout \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

install_git_checkout \
  "https://github.com/Aloxaf/fzf-tab.git" \
  "$HOME/.oh-my-zsh/custom/plugins/fzf-tab"

if command -v atuin >/dev/null 2>&1; then
  atuin_marker="$HOME/.local/share/atuin/.dotfiles_imported"
  if [[ ! -f "$atuin_marker" ]]; then
    echo "==> Importing existing shell history into Atuin"
    mkdir -p "$(dirname "$atuin_marker")"
    atuin import auto || true
    touch "$atuin_marker"
  fi
fi

if [[ ! -f "$HOME/.zshrc.local" ]]; then
  cp "$DOTFILES_DIR/zsh/.zshrc.local.example" "$HOME/.zshrc.local"
  chmod 600 "$HOME/.zshrc.local"
  echo "  [CREATED] $HOME/.zshrc.local"
fi

echo "==> Checking shell startup configuration"
if [[ -f "$HOME/.zshenv" ]] && grep -Eq '^[[:space:]]*(export[[:space:]]+)?ZDOTDIR=' "$HOME/.zshenv"; then
  echo "  [WARN] $HOME/.zshenv sets ZDOTDIR. Ensure it points to $HOME or remove it so the repo's ~/.zshrc loads."
fi

if command -v herdr >/dev/null 2>&1; then
  echo "  [OK] herdr found at $(command -v herdr)"
else
  echo "  [NOTE] herdr was not found; install Herdr separately for the h alias."
fi

echo "==> Requirements setup completed"
echo "Open a new terminal, or run: exec zsh"
