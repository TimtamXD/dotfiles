-- Opening a kind of file with no language support offers to install it.
-- Run: nvim -l tests/language_support_spec.lua   (python3 -m pytest tests runs it too)

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
package.path = root .. '/nvim/lua/?.lua;' .. package.path
local ls = require('config.language_support')

local failures, count = 0, 0
local function it(name, fn)
  count = count + 1
  local ok, err = pcall(fn)
  if not ok then failures = failures + 1; io.stdout:write('FAIL ', name, '\n  ', tostring(err), '\n') end
end
local function eq(want, got) assert(vim.deep_equal(want, got), ('want %s, got %s'):format(vim.inspect(want), vim.inspect(got))) end

-- A machine where Elixir and Zig have no support yet, Python is covered by an installed
-- server, TypeScript installs by itself, and Ruby's only server is switched off.
local function env(over)
  local e = {
    servers_for = function(ft)
      return ({ elixir = { 'lexical', 'elixirls', 'nextls' }, zig = { 'zls' }, python = { 'pylsp', 'basedpyright' },
        typescript = { 'ts_ls' }, ruby = { 'solargraph' }, fortran = { 'fortls' } })[ft] or {}
    end,
    package_for = function(server) return server ~= 'fortls' and server .. '-pkg' or nil end,
    is_installed = function(pkg) return pkg == 'basedpyright-pkg' end,
    is_disabled = function(server) return server == 'solargraph' end,
    installs_by_itself = function(server) return server == 'ts_ls' end,
    parser_for = function(ft) return ({ elixir = 'elixir', zig = 'zig', python = 'python', ruby = 'ruby' })[ft] end,
    has_parser = function(lang) return lang == 'python' end,
  }
  return vim.tbl_extend('force', e, over or {})
end

it('a new language offers its servers and its parser', function()
  eq({ servers = { 'elixirls', 'lexical', 'nextls' }, parser = 'elixir' }, ls.missing('elixir', env()))
end)

it('a language whose server is already installed only needs what else is missing', function()
  eq({ servers = {}, parser = nil }, ls.missing('python', env()))
end)

it('a language that installs by itself is not asked about', function()
  eq({ servers = {}, parser = nil }, ls.missing('typescript', env()))
end)

it('a server switched off on purpose is never offered', function()
  eq({ servers = {}, parser = 'ruby' }, ls.missing('ruby', env()))
end)

it('a server mason cannot install is not offered', function()
  eq({ servers = {}, parser = nil }, ls.missing('fortran', env()))
end)

it('the prompt offers each server with the parser, then Not now and Never', function()
  local labels = vim.tbl_map(function(c) return c.label end, ls.choices('zig', ls.missing('zig', env())))
  eq({ 'Install zls + zig parser', 'Not now', 'Never ask for zig files' }, labels)
end)

it('with only a parser missing the prompt offers just the parser', function()
  local choices = ls.choices('ruby', ls.missing('ruby', env()))
  eq('Install the ruby parser (highlighting, folds, text objects)', choices[1].label)
  eq({}, choices[1].servers)
  eq('ruby', choices[1].parser)
end)

it('nothing missing means no prompt', function()
  eq({}, ls.choices('python', ls.missing('python', env())))
end)

it('scratch buffers, terminals and help are never checked', function()
  eq(false, ls.should_check('lua', 'terminal', { never = {} }))
  eq(false, ls.should_check('', '', { never = {} }))
  eq(true, ls.should_check('zig', '', { never = {} }))
end)

it('a filetype answered Never is not checked again', function()
  eq(false, ls.should_check('zig', '', { never = { zig = true } }))
end)

it('Never is remembered across sessions', function()
  local path = vim.fn.tempname()
  ls.save_decisions({ never = { zig = true } }, path)
  eq({ never = { zig = true } }, ls.load_decisions(path))
end)

it('a missing or broken state file means nothing was decided yet', function()
  eq({ never = {} }, ls.load_decisions(vim.fn.tempname()))
  local path = vim.fn.tempname(); vim.fn.writefile({ 'not json' }, path)
  eq({ never = {} }, ls.load_decisions(path))
end)

it('the progress bar fills with the steps done', function()
  eq('██████████░░░░░░░░░░  50%  installing zls server', ls.progress_bar(1, 2, 'installing zls server'))
  eq('████████████████████ 100%  done', ls.progress_bar(2, 2, 'done'))
end)

io.stdout:write(('%d passed, %d failed\n'):format(count - failures, failures))
os.exit(failures == 0 and 0 or 1)
