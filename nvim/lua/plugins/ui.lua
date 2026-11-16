-- UI-related plugins.
---@diagnostic disable: missing-fields

local Plug = require('utils.plug_utils').Plug
local PlugConfig = require('utils.plug_utils').PlugConfig
local UpdateRemotePlugins = require('utils.plug_utils').UpdateRemotePlugins

-- Cheap check: lazy.nvim v10+ evaluates `cond` during startup, and config.pynvim starts the
-- Python host (~30ms). init.lua still runs config.pynvim right after startup (installs pynvim if missing).
local has_py3 = function() return vim.fn.executable(vim.g.python3_host_prog or 'python3') == 1 end

return {
  -- Basic UI Components
  Plug 'MunifTanjim/nui.nvim' { lazy = true };  -- see config/ui.lua
  Plug 'stevearc/dressing.nvim' { event = 'VeryLazy', config = require 'config.ui'.setup_dressing };
  Plug 'skywind3000/vim-quickui' {
    event = 'VeryLazy',
    init = require('config.ui').init_quickui,
    config = require('config.ui').setup_quickui,
  };

  -- Image
  Plug '3rd/image.nvim' {
    event = 'VeryLazy',  -- TODO support startup arguments
    config = require('config.ui').setup_image,
  };

  -- FZF & Grep
  Plug 'junegunn/fzf' {
    name = 'fzf',
    -- install.sh keeps fzf in ~/.fzf; without it lazy.nvim installs the plugin like any other
    dir = vim.fn.isdirectory(vim.fn.expand("$HOME/.fzf")) == 1 and '~/.fzf' or nil,
    build = './install --bin',
    cmd = 'FZF', func = 'fzf#*',
  };
  Plug 'ibhagwan/fzf-lua' {
    -- No version: fzf-lua stopped tagging releases at 0.7 (Apr 2025), which breaks on Neovim 0.12.
    -- Track main; lazy-lock.json pins the exact commit.
    version = false,
    event = { 'VeryLazy', 'CmdlineEnter' },
    config = require('config.fzf').setup,
  };
  Plug 'rking/ag.vim' { func = 'ag#*', lazy = true };

  -- Telescope (config/telescope.lua)
  Plug 'nvim-telescope/telescope.nvim' {
    enabled = vim.fn.has('nvim-0.9.0') > 0,
    event = 'CmdlineEnter',
    config = function()
      require('config.telescope').setup()
    end,
  };

  -- Terminal
  Plug 'voldikss/vim-floaterm' { event = 'CmdlineEnter' };

  -- Wildmenu
  Plug 'wookayin/wilder.nvim' {
    dependencies = {'romgrk/fzy-lua-native'},
    cond = has_py3,
    build = UpdateRemotePlugins,
    event = 'CmdlineEnter',
    func = 'wilder#*',
  };

  -- Explorer
  Plug 'nvim-neo-tree/neo-tree.nvim' {
    branch = 'main',
    version = '>=3.34',
    init = function() vim.g.neo_tree_remove_legacy_commands = 1; end,
    config = require('config.neotree').setup_neotree,
  };

  -- Navigation
  Plug 'vim-voom/VOoM' { cmd = { 'Voom', 'VoomToggle' } };
  Plug 'majutsushi/tagbar' { cmd = { 'Tagbar', 'TagbarOpen', 'TagbarToggle' } };

  -- Quickfix
  Plug 'kevinhwang91/nvim-bqf' { ft = 'qf', config = require('config.quickfix').setup_bqf };

  -- Marks and Signs
  Plug 'kshenoy/vim-signature' {
    event = 'VeryLazy',
    config = function()
      -- hlgroups are registered on VimEnter, so need to setup after lazy loading
      pcall(vim.fn['signature#utils#SetupHighlightGroups'])
    end
  };
  Plug 'vim-scripts/errormarker.vim' { event = 'VeryLazy' };
}
