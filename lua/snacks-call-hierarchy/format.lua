local snacks_format = require("snacks.picker.format")

local M = {}

---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
function M.call_hierarchy(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]

  if item.parent then
    vim.list_extend(ret, snacks_format.tree(item, picker))
  end

  -- Same width in both branches to keep labels aligned
  if item.expandable and not item.expanded then
    ret[#ret + 1] = { "▶ ", "Comment" }
  else
    ret[#ret + 1] = { "  ", "SnacksPickerTree" }
  end

  local kind = item.kind or "Unknown"
  local kind_icon = picker.opts.icons.kinds[kind]
  if kind_icon then
    ret[#ret + 1] = { kind_icon, "SnacksPickerIcon" .. kind }
  end
  ret[#ret + 1] = { " " }

  local name = vim.trim((item.name or ""):gsub("\r?\n", " "))
  Snacks.picker.highlight.format(item, name, ret)

  if item.is_root then
    local state = require("snacks-call-hierarchy.finder").get_state(picker)
    if state then
      local label = state.direction == "incoming" and "Incoming" or "Outgoing"
      ret[#ret + 1] = { " [" .. label .. "]", "Comment" }
    end
  end

  if item.file then
    local path = item.display_path or vim.fn.fnamemodify(item.file, ":~:.")
    ret[#ret + 1] = { "  " .. path, "Comment" }
    if item.pos then
      ret[#ret + 1] = { ":" .. item.pos[1], "Comment" }
    end
  end

  return ret
end

return M
