-- Editor quality-of-life plugins and lazygit integration
return {
  -- Noice: tune LSP doc borders and UI
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = true,
      },
    },
  },

  -- Mini.indentscope: animated indent guide lines
  {
    "nvim-mini/mini.indentscope",
    opts = {
      symbol = "│",
      options = { try_as_border = true },
    },
  },

  -- Lazygit inside Neovim (opens in a floating terminal)
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>",            desc = "LazyGit" },
      { "<leader>gG", "<cmd>LazyGitCurrentFile<cr>", desc = "LazyGit (current file)" },
      { "<leader>gf", "<cmd>LazyGitFilter<cr>",      desc = "LazyGit file history" },
    },
  },

  -- Which-key: label the git group
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>g", group = "git / lazygit" },
      },
    },
  },

  -- Telescope: sensible defaults
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          prompt_position = "top",
          horizontal = {
            preview_width = 0.65, -- Larger preview size for photos, PDFs, and code
          },
        },
        sorting_strategy = "ascending",
        winblend = 0,
        file_ignore_patterns = {
          "%.git/",
          "node_modules/",
          "%.DS_Store",
          "dist/",
          "target/",
          "%.lock",
          "Library/",
          "Applications/",
          "System/",
          "%.cache/",
          "%.npm/",
          "%.cargo/",
          "%.gemini/",
          "%.rustup/",
          "%.local/",
          "%.cocoapods/",
          "%.android/",
          "%.cursor/",
          "%.gradle/",
        },
      },
    },
  },

  -- Better buffer delete (keeps window layout)
  {
    "nvim-mini/mini.bufremove",
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete Buffer" },
      { "<leader>bD", function() require("mini.bufremove").delete(0, true) end,  desc = "Delete Buffer (Force)" },
    },
  },

  -- Flash: fast navigation within buffer
  {
    "folke/flash.nvim",
    opts = {
      modes = {
        search = { enabled = true },
        char = { enabled = true },
      },
    },
  },

  -- Herdr integration (annotations, file pick, agent reviews)
  {
    "ChmaraX/herdr-nvim",
    opts = {},
  },
}

