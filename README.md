# Personal Dotfiles

Custom configuration files, shell scripts, window management rules, and AI agent skills for macOS.

---

## 📦 What's Included

- **Shell (`zsh/`)**: `.zshrc` with Oh-My-Zsh plugins, `obdaily` Obsidian date helper, and secret decoupling via `~/.zshrc.local`.
- **Prompt (`starship/`)**: Starship cross-shell prompt configuration (`starship.toml`).
- **Git (`git/`)**: `.gitconfig` with aliases and global `.gitignore`.
- **Window Management & Hotkeys (`config/`)**:
  - `aerospace/`: AeroSpace tiling window manager config.
  - `karabiner/`: Karabiner-Elements key remapping.
- **Terminals & Editors (`config/`)**:
  - `kitty/`: Kitty terminal configuration.
  - `ghostty/`: Ghostty terminal configuration.
  - `nvim/`: Neovim / LazyVim IDE setup.
- **AI Agent Skills (`agents/skills/`)**:
  - `obsidian-project-tracker`: Automated Obsidian project & Kanban ledger management.
  - `vimark-feature-workflow`: Desktop app CI/delivery workflow.
  - `mobile-feature-workflow`: iOS & Android dual-platform workflow.

---

## 🚀 Quick Setup on a New Machine

```bash
# 1. Clone your dotfiles
git clone <your-repo-url> ~/dotfiles

# 2. Run the installer (backs up existing files and creates symlinks)
cd ~/dotfiles && ./install.sh

# 3. Add any machine-specific secrets to ~/.zshrc.local
# (e.g. API keys, passwords)
```
