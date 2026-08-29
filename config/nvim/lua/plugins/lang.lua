-- Language configuration for LazyVim
-- Covers: TypeScript/JS, Python, Rust, Go, Markdown, Docker, YAML, TOML, JSON
return {

  -- Additional Treesitter parsers beyond what extras provide
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, {
        "bash",
        "css",
        "dockerfile",
        "html",
        "javascript",
        "json",
        "json5",
        "jsonc",
        "lua",
        "luadoc",
        "make",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "rust",
        "sql",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      })
    end,
  },

  -- Mason: ensure key LSPs / formatters / linters are installed
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- Formatters
        "stylua",
        "prettier",
        "black",
        "isort",
        "shfmt",
        "gofumpt",
        -- Note: rustfmt ships with rustup, not Mason
        -- Linters
        "shellcheck",
        "eslint_d",
        "flake8",
        "golangci-lint",
        -- LSPs (mason supplements LazyVim extras)
        "pyright",
        "typescript-language-server",
        "gopls",
        "rust-analyzer",
        "dockerfile-language-server",
        "yaml-language-server",
        "taplo", -- TOML
        "marksman", -- Markdown
        "lua-language-server",
      },
    },
  },
}
