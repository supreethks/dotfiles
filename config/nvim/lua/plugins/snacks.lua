return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        -- Extend default sources to ignore system directories
        sources = {
          files = {
            exclude = {
              "Library",
              "Applications",
              "System",
              ".cache",
              ".npm",
              ".cargo",
              ".gemini",
              ".rustup",
              ".local",
              ".cocoapods",
              ".android",
              ".cursor",
              ".gradle",
            },
          },
          grep = {
            exclude = {
              "Library",
              "Applications",
              "System",
              ".cache",
              ".npm",
              ".cargo",
              ".gemini",
              ".rustup",
              ".local",
              ".cocoapods",
              ".android",
              ".cursor",
              ".gradle",
            },
          },
        },
        -- Customize the layout to give the preview window more space (65% width)
        layouts = {
          default = {
            layout = {
              box = "horizontal",
              width = 0.9,
              min_width = 120,
              height = 0.9,
              {
                box = "vertical",
                border = true,
                title = "{title} {live} {flags}",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              { win = "preview", title = "{preview}", border = true, width = 0.65 },
            },
          },
        },
      },
    },
  },
}
