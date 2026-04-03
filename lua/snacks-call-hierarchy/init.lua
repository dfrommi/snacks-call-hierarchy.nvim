local M = {}

---@class snacks-call-hierarchy.Config : snacks.picker.Config
---@field max_depth? integer Maximum tree depth (default 20)
---@field auto_expand_depth? integer Auto-expand depth on open (default 10)
---@field max_open_requests? integer Maximum child LSP requests during initial expansion (default 100)
---@field lsp_filter? fun(item: snacks-call-hierarchy.FilterItem, ctx: snacks-call-hierarchy.FilterContext): boolean Prune non-matching branches while expanding. The initial root is always included automatically.

---@param opts? snacks-call-hierarchy.Config
function M.setup(opts)
  opts = opts or {}

  local actions = require("snacks-call-hierarchy.actions")
  local finder = require("snacks-call-hierarchy.finder")
  local format = require("snacks-call-hierarchy.format")

  local sources = require("snacks.picker.config.sources")

  local max_depth = opts.max_depth or 20
  local auto_expand_depth = opts.auto_expand_depth or 10
  local max_open_requests = opts.max_open_requests or 100

  -- Strip options the user cannot override (locked by internal tree mechanics)
  local user_opts = vim.tbl_extend("force", opts, {})
  for _, k in ipairs({ "finder", "format", "tree", "sort", "max_depth", "auto_expand_depth", "max_open_requests", "lsp_filter" }) do
    user_opts[k] = nil
  end

  local keys = {
    ["<CR>"] = { "confirm", desc = "Open file" },
    ["<leader><space>"] = { "call_hierarchy_toggle_direction", desc = "Toggle incoming/outgoing direction" },
    ["za"] = { "call_hierarchy_toggle_expanded", desc = "Toggle expand/collapse" },
    ["gi"] = { "call_hierarchy_incoming", desc = "Re-root at selection, show incoming calls" },
    ["go"] = { "call_hierarchy_outgoing", desc = "Re-root at selection, show outgoing calls" },
  }

  -- Plugin defaults (user opts from setup() can override these)
  local defaults = { preview = "file" }

  -- Internal config that always wins over user opts
  ---@type snacks.picker.Config
  local locked = {
    tree = true,
    format = format.call_hierarchy,
    sort = { fields = { "idx" } },
    matcher = { sort_empty = false, keep_parents = true },
    actions = {
      call_hierarchy_toggle_expanded = actions.toggle,
      call_hierarchy_incoming = actions.reroot_incoming,
      call_hierarchy_outgoing = actions.reroot_outgoing,
      call_hierarchy_toggle_direction = actions.toggle_direction,
    },
    max_depth = max_depth,
    auto_expand_depth = auto_expand_depth,
    max_open_requests = max_open_requests,
    lsp_filter = opts.lsp_filter,
    win = {
      input = {
        keys = keys,
      },
      list = {
        keys = keys,
      },
    },
  }

  local base = vim.tbl_deep_extend("force", defaults, user_opts, locked)

  sources.call_hierarchy_in = vim.tbl_deep_extend("force", base, {
    finder = finder.incoming,
  })

  sources.call_hierarchy_out = vim.tbl_deep_extend("force", base, {
    finder = finder.outgoing,
  })
end

return M
