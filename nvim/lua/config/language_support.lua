-- Language support on demand.
--
-- Opening a kind of file this setup has no language server or tree-sitter parser for asks
-- whether to install them. "Yes" installs in the background (mason for the server,
-- nvim-treesitter for the parser) with a progress bar, then the server attaches to the
-- open buffers. "Never" is remembered per filetype; :LanguageSupport asks again.
--
-- Servers listed in config/lsp.lua's auto_lsp_servers install without asking; this covers
-- every other language. Tests: tests/language_support_spec.lua (nvim -l).

local M = {}

local STATE_FILE = vim.fn.stdpath('state') .. '/language-support.json'
local IGNORED_BUFTYPES = { nofile = true, terminal = true, help = true, prompt = true, quickfix = true }
local MAX_SERVER_CHOICES = 3

---------------------------------------------------------------------------------------------
-- What is missing (pure: everything it looks at comes in through `env`)
---------------------------------------------------------------------------------------------

---@class LanguageSupportEnv
---@field servers_for fun(ft: string): string[]   lspconfig server names mason knows for ft
---@field package_for fun(server: string): string? mason package name of a server
---@field is_installed fun(package: string): boolean
---@field is_disabled fun(server: string): boolean  switched off on purpose in config/lsp.lua
---@field installs_by_itself fun(server: string): boolean  in auto_lsp_servers
---@field parser_for fun(ft: string): string?    tree-sitter language nvim-treesitter can install
---@field has_parser fun(lang: string): boolean

---@return { servers: string[], parser: string? }  what could be offered for ft; empty when nothing
function M.missing(ft, env)
  local servers = {}
  for _, server in ipairs(env.servers_for(ft)) do
    local package = env.package_for(server)
    if package == nil or env.is_disabled(server) then
      -- not installable through mason, or deliberately off
    elseif env.is_installed(package) or env.installs_by_itself(server) then
      return { servers = {}, parser = M._missing_parser(ft, env) }  -- this filetype is covered
    else
      servers[#servers + 1] = server
    end
  end
  table.sort(servers)
  return { servers = vim.list_slice(servers, 1, MAX_SERVER_CHOICES), parser = M._missing_parser(ft, env) }
end

function M._missing_parser(ft, env)
  local lang = env.parser_for(ft)
  if lang and not env.has_parser(lang) then return lang end
  return nil
end

---@return boolean whether ft should be looked at at all
function M.should_check(ft, buftype, decisions)
  return ft ~= '' and not IGNORED_BUFTYPES[buftype] and not (decisions.never or {})[ft]
end

--- The choices shown in the prompt, and what each one installs.
---@return { label: string, servers: string[], parser: string?, never: boolean? }[]
function M.choices(ft, missing)
  local choices = {}
  local parser_note = missing.parser and (' + %s parser'):format(missing.parser) or ''
  for _, server in ipairs(missing.servers) do
    choices[#choices + 1] = { label = ('Install %s%s'):format(server, parser_note), servers = { server }, parser = missing.parser }
  end
  if #missing.servers == 0 and missing.parser then
    choices[#choices + 1] = { label = ('Install the %s parser (highlighting, folds, text objects)'):format(missing.parser), servers = {}, parser = missing.parser }
  end
  if #choices == 0 then return {} end
  choices[#choices + 1] = { label = 'Not now', servers = {} }
  choices[#choices + 1] = { label = ('Never ask for %s files'):format(ft), servers = {}, never = true }
  return choices
end

--- "███████░░░ 70%  tailwindcss" for a step count and what is installing now.
function M.progress_bar(done, total, what, width)
  width = width or 20
  local filled = total > 0 and math.floor(width * done / total + 0.5) or width
  local percent = total > 0 and math.floor(100 * done / total + 0.5) or 100
  return ('%s%s %3d%%  %s'):format(('█'):rep(filled), ('░'):rep(width - filled), percent, what)
end

---------------------------------------------------------------------------------------------
-- Remembered decisions
---------------------------------------------------------------------------------------------

function M.load_decisions(path)
  local ok, lines = pcall(vim.fn.readfile, path or STATE_FILE)
  if not ok or #lines == 0 then return { never = {} } end
  local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, '\n'))
  if not decoded_ok or type(data) ~= 'table' then return { never = {} } end
  data.never = data.never or {}
  return data
end

function M.save_decisions(decisions, path)
  path = path or STATE_FILE
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  vim.fn.writefile({ vim.json.encode(decisions) }, path)
end

---------------------------------------------------------------------------------------------
-- The real environment: mason, mason-lspconfig, nvim-treesitter
---------------------------------------------------------------------------------------------

function M.env()
  local mappings = vim.F.npcall(function() return require('mason-lspconfig').get_mappings() end) or {}
  local registry = require('mason-registry')
  local lsp = require('config.lsp')
  local ts_parsers = vim.F.npcall(require, 'nvim-treesitter.parsers')
  return {
    servers_for = function(ft) return (mappings.filetypes or {})[ft] or {} end,
    package_for = function(server)
      local package = (mappings.lspconfig_to_package or {})[server]
      return package and registry.has_package(package) and package or nil
    end,
    is_installed = function(package) return registry.is_installed(package) end,
    is_disabled = function(server)
      return lsp.lsp_setup_opts[server] == false or (lsp.auto_lsp_servers or {})[server] == false
    end,
    installs_by_itself = function(server) return (lsp.auto_lsp_servers or {})[server] == true end,
    parser_for = function(ft)
      if not ts_parsers then return nil end
      local lang = vim.treesitter.language.get_lang(ft) or ft
      local configs = ts_parsers.get_parser_configs and ts_parsers.get_parser_configs() or {}
      return configs[lang] and lang or nil
    end,
    has_parser = function(lang) return require('config.treesitter').has_parser(lang) end,
  }
end

---------------------------------------------------------------------------------------------
-- Installing, with a progress bar
---------------------------------------------------------------------------------------------

--- fidget's progress bar when it is loaded, otherwise one notification updated in place.
local function progress_reporter(title)
  local ok, fidget_progress = pcall(require, 'fidget.progress')
  if ok and fidget_progress.handle then
    local handle = fidget_progress.handle.create { title = title, message = 'starting', percentage = 0, lsp_client = { name = 'language support' } }
    return {
      report = function(done, total, what)
        handle:report { message = M.progress_bar(done, total, what), percentage = math.floor(100 * done / math.max(total, 1)) }
      end,
      finish = function(message) handle.message = message; handle:finish() end,
    }
  end
  local record
  local notify = function(msg, level)
    record = vim.notify(msg, level or vim.log.levels.INFO, { title = title, replace = record, hide_from_history = true })
  end
  return {
    report = function(done, total, what) notify(M.progress_bar(done, total, what)) end,
    finish = function(message, level) notify(message, level) end,
  }
end

local function install_server(server, on_done, on_output)
  local registry = require('mason-registry')
  local package_name = require('mason-lspconfig').get_mappings().lspconfig_to_package[server]
  local pkg = registry.get_package(package_name)
  pkg:once('install:success', vim.schedule_wrap(function() on_done(true) end))
  pkg:once('install:failed', vim.schedule_wrap(function() on_done(false) end))
  local handle = pkg:install()
  if handle and handle.on then
    handle:on('stdout', vim.schedule_wrap(function(chunk) on_output(vim.trim(chunk):match('[^\n]*$') or '') end))
  end
end

local function install_parser(lang, on_done)
  vim.cmd('silent! TSInstall ' .. lang)
  local timer, waited = vim.uv.new_timer(), 0
  timer:start(500, 500, vim.schedule_wrap(function()
    waited = waited + 500
    local has = require('config.treesitter').has_parser(lang)
    if has or waited > 180000 then
      timer:stop(); timer:close()
      on_done(has)
    end
  end))
end

--- Install a choice's servers, then its parser, one at a time.
function M.install(ft, choice)
  local steps = {}
  for _, server in ipairs(choice.servers) do steps[#steps + 1] = { kind = 'server', name = server } end
  if choice.parser then steps[#steps + 1] = { kind = 'parser', name = choice.parser } end
  local progress = progress_reporter(('Language support: %s'):format(ft))
  local failed = {}

  local function step(i)
    if i > #steps then
      if #failed == 0 then
        progress.finish(('%s is ready'):format(ft))
      else
        progress.finish(('%s: %s did not install, see :Mason or :TSInstallInfo'):format(ft, table.concat(failed, ', ')), vim.log.levels.WARN)
      end
      return
    end
    local s = steps[i]
    progress.report(i - 1, #steps, ('installing %s %s'):format(s.name, s.kind))
    local done = function(ok)
      if not ok then failed[#failed + 1] = s.name end
      step(i + 1)
    end
    if s.kind == 'server' then
      install_server(s.name, done, function(line)
        if line ~= '' then progress.report(i - 1, #steps, ('%s: %s'):format(s.name, line:sub(1, 60))) end
      end)
    else
      install_parser(s.name, done)
    end
  end

  require('mason-registry').refresh(function() vim.schedule(function() step(1) end) end)
end

---------------------------------------------------------------------------------------------
-- Asking
---------------------------------------------------------------------------------------------

local asked = {}  -- filetypes asked about in this session

function M.ask(ft, opts)
  opts = opts or {}
  local decisions = M.load_decisions()
  if opts.force then decisions.never[ft] = nil end
  if not M.should_check(ft, opts.buftype or '', decisions) then return end
  local ok, env = pcall(M.env)
  if not ok then return end  -- mason not ready yet
  local choices = M.choices(ft, M.missing(ft, env))
  if #choices == 0 then
    if opts.force then vim.notify(('%s already has language support'):format(ft), vim.log.levels.INFO, { title = 'Language support' }) end
    return
  end
  vim.ui.select(choices, {
    prompt = ('No language support for %s files yet. Install it?'):format(ft),
    format_item = function(c) return c.label end,
  }, function(choice)
    if not choice then return end
    if choice.never then
      decisions.never[ft] = true
      M.save_decisions(decisions)
    elseif #choice.servers > 0 or choice.parser then
      M.install(ft, choice)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('language_support', { clear = true }),
    callback = function(args)
      local ft = args.match
      if asked[ft] then return end
      asked[ft] = true
      -- after the buffer is drawn and mason's own FileType handlers have run
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          M.ask(ft, { buftype = vim.bo[args.buf].buftype })
        end
      end, 300)
    end,
  })
  -- buffers that were already open before the LSP setup loaded
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local ft = vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype or ''
    if ft ~= '' and not asked[ft] then
      asked[ft] = true
      vim.defer_fn(function() M.ask(ft, { buftype = vim.bo[buf].buftype }) end, 300)
    end
  end
  vim.api.nvim_create_user_command('LanguageSupport', function(cmd)
    M.ask(cmd.args ~= '' and cmd.args or vim.bo.filetype, { force = true, buftype = vim.bo.buftype })
  end, { nargs = '?', complete = 'filetype', desc = 'Install a language server and parser for this filetype' })
end

return M
