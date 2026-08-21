-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Note: Neovim is always UTF-8; encoding/termencoding cannot be set.

-- ── Visual ────────────────────────────────────────────────────────────────────
vim.opt.relativenumber = true       -- relative line numbers (jump with <N>j/k)
vim.opt.scrolloff = 8               -- keep 8 lines of context around cursor
vim.opt.sidescrolloff = 8
vim.opt.wrap = false                -- no soft line wrapping
vim.opt.cursorline = true           -- highlight current line
vim.opt.signcolumn = "yes"          -- always show sign column (no layout shift)
vim.opt.colorcolumn = "120"         -- soft ruler at 120 chars

-- ── Indentation ───────────────────────────────────────────────────────────────
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true            -- spaces, not tabs
vim.opt.smartindent = true
vim.opt.autoindent = true

-- ── Search ────────────────────────────────────────────────────────────────────
vim.opt.ignorecase = true
vim.opt.smartcase = true            -- case-sensitive when query has uppercase

-- ── Files & Undo ──────────────────────────────────────────────────────────────
vim.opt.undofile = true             -- persistent undo across sessions
vim.opt.swapfile = false
vim.opt.backup = false

-- ── Performance ───────────────────────────────────────────────────────────────
vim.opt.updatetime = 200            -- faster CursorHold (LSP diagnostics)
vim.opt.timeoutlen = 300            -- faster which-key popup

-- ── Window splits ─────────────────────────────────────────────────────────────
vim.opt.splitright = true           -- vertical split opens to the right
vim.opt.splitbelow = true           -- horizontal split opens below

-- ── Clipboard ─────────────────────────────────────────────────────────────────
vim.opt.clipboard = "unnamedplus"   -- sync with system clipboard
