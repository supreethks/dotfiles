#!/usr/bin/env bash
set -euo pipefail

# Free Cmd+H for Herdr pane-left focus by remapping Ghostty's Hide shortcut.
defaults write com.mitchellh.ghostty NSUserKeyEquivalents '{"Hide Ghostty" = "@~^h";}'
echo "Remapped Ghostty Hide Ghostty to Ctrl+Cmd+Option+H."
echo "Restart Ghostty if Cmd+H still hides the app."
