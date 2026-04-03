local M = {}

---@class snacks-call-hierarchy.Config
---@field max_depth? integer Maximum tree depth (default 20)
---@field auto_expand_depth? integer Auto-expand depth on open (default 10)

---@param opts? snacks-call-hierarchy.Config
function M.setup(opts)
  opts = opts or {}

  local actions = require("snacks-call-hierarchy.actions")
  local finder = require("snacks-call-hierarchy.finder")
  local format = require("snacks-call-hierarchy.format")

  local sources = require("snacks.picker.config.sources")

  ---@type snacks.picker.Config
  local base = {
    preview = "file",
    tree = true,
    format = format.call_hierarchy,
    sort = { fields = { "idx" } },
    matcher = { sort_empty = false, keep_parents = true },
    actions = {
      confirm = actions.confirm,
      call_hierarchy_jump = actions.jump,
      call_hierarchy_incoming = actions.switch_incoming,
      call_hierarchy_outgoing = actions.switch_outgoing,
      call_hierarchy_reroot = actions.reroot,
    },
    max_depth = opts.max_depth or 20,
    auto_expand_depth = opts.auto_expand_depth or 10,
    win = {
      input = {
        keys = {
          ["gi"] = { "call_hierarchy_incoming", mode = { "n", "i" }, desc = "Switch to incoming calls" },
          ["go"] = { "call_hierarchy_outgoing", mode = { "n", "i" }, desc = "Switch to outgoing calls" },
        },
      },
      list = {
        keys = {
          ["o"] = { "call_hierarchy_jump", desc = "Jump to location" },
          ["<CR>"] = { "confirm", desc = "Toggle / Jump" },
          ["r"] = { "call_hierarchy_reroot", desc = "Re-root from selection" },
          ["gi"] = { "call_hierarchy_incoming", desc = "Switch to incoming calls" },
          ["go"] = { "call_hierarchy_outgoing", desc = "Switch to outgoing calls" },
        },
      },
    },
  }

  sources.call_hierarchy_in = vim.tbl_deep_extend("force", base, {
    finder = finder.incoming,
  })

  sources.call_hierarchy_out = vim.tbl_deep_extend("force", base, {
    finder = finder.outgoing,
  })
end

return M
