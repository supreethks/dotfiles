-- Kanagawa colorscheme for LazyVim
return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      compile = true,
      undercurl = true,
      commentStyle = { italic = true },
      functionStyle = {},
      keywordStyle = { italic = true },
      statementStyle = { bold = true },
      typeStyle = {},
      transparent = false,
      dimInactive = false,
      terminalColors = true,
      colors = {
        theme = {
          all = {
            ui = { bg_gutter = "none" },
          },
        },
      },
      overrides = function(colors)
        local theme = colors.theme
        return {
          -- Telescope floating windows
          TelescopeTitle = { fg = theme.ui.special, bold = true },
          TelescopePromptNormal = { bg = theme.ui.bg_p1 },
          TelescopePromptBorder = { fg = theme.ui.bg_p1, bg = theme.ui.bg_p1 },
          TelescopeResultsNormal = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m1 },
          TelescopeResultsBorder = { fg = theme.ui.bg_m1, bg = theme.ui.bg_m1 },
          TelescopePreviewNormal = { bg = theme.ui.bg_dim },
          TelescopePreviewBorder = { bg = theme.ui.bg_dim, fg = theme.ui.bg_dim },
          -- Completion menu
          Pmenu = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 },
          PmenuSel = { fg = "NONE", bg = theme.ui.bg_p2 },
          PmenuSbar = { bg = theme.ui.bg_m1 },
          PmenuThumb = { bg = theme.ui.bg_p2 },
          -- NeoTree
          NeoTreeNormal = { fg = theme.ui.fg, bg = theme.ui.bg_m3 },
          NeoTreeNormalNC = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m3 },
        }
      end,
      theme = "wave",              -- "wave" (dark) | "lotus" (light) | "dragon" (darker)
      background = { dark = "wave", light = "lotus" },
    },
  },

  -- Tell LazyVim to use kanagawa
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "kanagawa" },
  },
}
