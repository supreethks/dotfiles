# Personal Dotfiles

Custom configuration files, shell scripts, window management rules, and AI agent skills for macOS.

---

## 📦 What's Included

- **Shell (`zsh/`)**: `.zshrc` with Oh-My-Zsh plugins, Atuin history, fzf widgets, AIChat (Cmd+E via AGY), `obdaily`, and secret decoupling via `~/.zshrc.local`.
- **AIChat (`config/aichat/`)**: local config plus a small proxy so AIChat uses a logged-in `agy` CLI.
- **Atuin (`config/atuin/`)**: fuzzy command history (local only, no sync).
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

# 2. Install Homebrew tools, Ghostty, Nerd Font, agent CLIs, Oh My Zsh, and plugins
cd ~/dotfiles && ./install-requirements.sh

# 3. Run the installer (backs up existing files and creates symlinks)
./install.sh

# 4. Add any machine-specific secrets to ~/.zshrc.local
# (e.g. API keys, passwords)
```

`install-requirements.sh` is safe to run again on another macOS machine. It uses
the `Brewfile` for repeatable Homebrew installs and does not remove packages
that are not listed there. It uses each tool's official shell installer for
Herdr, Codex, Claude Code, AGY, and Cursor Agent when they are missing;
authentication remains a one-time manual step for each tool.
