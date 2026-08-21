-- Language extras for LazyVim
-- Covers: TypeScript/JS, Python, Rust, Go, Markdown, Docker, YAML, TOML, JSON
return {
  -- LazyVim language extras (handles LSP + Treesitter + formatter per language)
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.rust" },
  { import = "lazyvim.plugins.extras.lang.go" },
  { import = "lazyvim.plugins.extras.lang.docker" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.toml" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.json" },

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
