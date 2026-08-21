-- Mason headless installer script
-- Run: nvim --headless -u NONE -l ~/.config/nvim/scripts/mason_install.lua

-- Bootstrap lazy.nvim so mason is available
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(lazypath)

-- We need to load the full nvim config to get mason loaded
-- Then schedule the installs

local packages = {
  -- LSP servers
  "pyright",
  "typescript-language-server",
  "gopls",
  "rust-analyzer",
  "dockerfile-language-server",
  "yaml-language-server",
  "taplo",
  "marksman",
  "lua-language-server",
  -- Formatters
  "prettier",
  "black",
  "isort",
  "shfmt",
  "gofumpt",
  "goimports",
  "stylua",
  -- Linters
  "shellcheck",
  "eslint_d",
  "flake8",
  "golangci-lint",
}

vim.schedule(function()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    print("Mason registry not available: " .. tostring(registry))
    vim.cmd("qa!")
    return
  end

  registry.refresh(function()
    local pending = #packages
    for _, pkg_name in ipairs(packages) do
      local ok2, pkg = pcall(registry.get_package, pkg_name)
      if ok2 and not pkg:is_installed() then
        print("Installing: " .. pkg_name)
        pkg:install():on("closed", function()
          pending = pending - 1
          print("Done: " .. pkg_name .. " (" .. pending .. " remaining)")
          if pending == 0 then
            print("All packages installed!")
            vim.cmd("qa!")
          end
        end)
      else
        pending = pending - 1
        if ok2 then
          print("Already installed: " .. pkg_name)
        else
          print("Not found in registry: " .. pkg_name)
        end
        if pending == 0 then
          print("All packages installed!")
          vim.cmd("qa!")
        end
      end
    end
  end)
end)
