-- This file contains the configuration overrides for specific Neovim plugins.

local is_termux = vim.env.TERMUX_VERSION ~= nil
  or (vim.env.PREFIX and vim.env.PREFIX:find("com.termux", 1, true) ~= nil)

return {
  -- Change configuration for trouble.nvim
  {
    -- Plugin: trouble.nvim
    -- URL: https://github.com/folke/trouble.nvim
    -- Description: A pretty list for showing diagnostics, references, telescope results, quickfix and location lists.
    "folke/trouble.nvim",
    -- Options to be merged with the parent specification
    opts = { use_diagnostic_signs = true }, -- Use diagnostic signs for trouble.nvim
  },

  -- Add symbols-outline.nvim plugin
  {
    -- Plugin: symbols-outline.nvim
    -- URL: https://github.com/simrat39/symbols-outline.nvim
    -- Description: A tree like view for symbols in Neovim using the Language Server Protocol.
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline", -- Command to open the symbols outline
    keys = { { "<leader>cs", "<cmd>SymbolsOutline<cr>", desc = "Symbols Outline" } }, -- Keybinding to open the symbols outline
    config = true, -- Use default configuration
  },

  -- Remove inlay hints from default configuration
  {
    -- Plugin: nvim-lspconfig
    -- URL: https://github.com/neovim/nvim-lspconfig
    -- Description: Quickstart configurations for the Neovim LSP client.
    "neovim/nvim-lspconfig",
    event = "VeryLazy", -- Load this plugin on the 'VeryLazy' event
    opts = {
      inlay_hints = { enabled = false }, -- Disable inlay hints
      servers = {
        angularls = {
          -- Configuration for Angular Language Server
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("angular.json", "project.json")(fname)
          end,
        },
        nil_ls = {
          -- Configuration for nil (Nix Language Server), already installed via nix
          cmd = { "nil" },
          autostart = true,
          mason = false, -- Explicitly disable mason management for nil_ls
          settings = {
            ["nil"] = {
              formatting = { command = { "nixpkgs-fmt" } },
            },
          },
        },
        lua_ls = is_termux and {
          cmd = { "lua-language-server" },
          autostart = true,
          mason = false,
        } or nil,
      },
    },
  },

  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      if not is_termux then
        return
      end
      opts.ensure_installed = opts.ensure_installed or {}
      opts.ensure_installed = vim.tbl_filter(function(server)
        return server ~= "lua_ls"
      end, opts.ensure_installed)
    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      if not is_termux then
        return
      end
      opts.ensure_installed = opts.ensure_installed or {}
      local blocked = {
        stylua = true,
        ["lua-language-server"] = true,
        lua_ls = true,
      }
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return not blocked[tool]
      end, opts.ensure_installed)
    end,
  },
}
