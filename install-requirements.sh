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
