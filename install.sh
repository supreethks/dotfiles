#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

echo "==> Bootstrapping dotfiles from $DOTFILES_DIR"

link_file() {
  local src="$1"
  local dest="$2"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  [SKIP] $dest is already linked to $src"
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    echo "  [BACKUP] $dest -> $BACKUP_DIR/"
    mv "$dest" "$BACKUP_DIR/"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  echo "  [LINK] $dest -> $src"
}

# 1. Shell & Git
link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"
link_file "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

# 2. Starship & App Configs
link_file "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
link_file "$DOTFILES_DIR/config/aerospace" "$HOME/.config/aerospace"
link_file "$DOTFILES_DIR/config/karabiner" "$HOME/.config/karabiner"
link_file "$DOTFILES_DIR/config/kitty" "$HOME/.config/kitty"
link_file "$DOTFILES_DIR/config/ghostty" "$HOME/.config/ghostty"
link_file "$DOTFILES_DIR/config/zellij" "$HOME/.config/zellij"
link_file "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"

# 3. Agent Skills & Search Config
link_file "$DOTFILES_DIR/agents/skills" "$HOME/.agents/skills"
link_file "$DOTFILES_DIR/search/.ignore" "$HOME/.ignore"
link_file "$DOTFILES_DIR/search/.ignore" "$HOME/.fdignore"
link_file "$DOTFILES_DIR/search/.ignore" "$HOME/.rgignore"

# 4. Local secrets setup
if [ ! -f "$HOME/.zshrc.local" ]; then
  cp "$DOTFILES_DIR/zsh/.zshrc.local.example" "$HOME/.zshrc.local"
  chmod 600 "$HOME/.zshrc.local"
  echo "  [CREATED] Initialized ~/.zshrc.local from example template"
fi

echo "==> Dotfiles setup completed successfully!"
