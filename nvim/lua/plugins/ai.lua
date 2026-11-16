-- Claude Code inside Neovim: a Claude terminal beside your code that sees the open file and
-- your selection, searches the project, and proposes edits as diffs to accept or reject.
-- Runs the `claude` CLI with its own sign-in (no API key).
---@diagnostic disable: missing-fields

return {
  {
    "coder/claudecode.nvim",
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSelectModel", "ClaudeCodeAdd", "ClaudeCodeSend",
      "ClaudeCodeTreeAdd", "ClaudeCodeStatus", "ClaudeCodeStart", "ClaudeCodeStop", "ClaudeCodeOpen",
      "ClaudeCodeClose", "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny", "ClaudeCodeCloseAllDiffs",
    },
    opts = {
      terminal = { provider = "native", split_side = "right", split_width_percentage = 0.4 },
    },
    keys = {
      { "<leader>a", nil, desc = "Claude" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude: open / close (ask anything)" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude: jump to it" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Claude: resume an earlier chat" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Claude: continue the last chat" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Claude: pick a model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: add this file" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: send the selection" },
      { "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Claude: add the file under the cursor",
        ft = { "neo-tree", "NvimTree", "oil", "netrw" } },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept the edit" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: reject the edit" },
    },
  },
}
