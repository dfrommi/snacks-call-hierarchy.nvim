local finder = require("snacks-call-hierarchy.finder")

local M = {}

--- Toggle expand/collapse. Does nothing on leaf nodes.
---@param picker snacks.Picker
---@param item snacks.picker.Item
function M.toggle(picker, item)
  if not item then
    return
  end
  local state = finder.get_state(picker)
  if not state then
    return
  end
  local node = state.nodes[item.node_id]
  if not node then
    return
  end

  if node.children_ids and #node.children_ids == 0 then
    return
  end

  state:toggle(item.node_id, function()
    vim.schedule(function()
      picker.list:set_target()
      picker:find()
    end)
  end)
end

---@param picker snacks.Picker
function M.switch_incoming(picker)
  M._switch_direction(picker, "incoming")
end

---@param picker snacks.Picker
function M.switch_outgoing(picker)
  M._switch_direction(picker, "outgoing")
end

---@param picker snacks.Picker
---@param lsp_item lsp.CallHierarchyItem
---@param direction "incoming"|"outgoing"
local function replace_state(picker, lsp_item, direction)
  local old = finder.get_state(picker)
  local State = require("snacks-call-hierarchy.state")
  local new_state = State.new(old.client, lsp_item, direction, old.max_depth)
  finder.set_state(picker, new_state)

  local auto_expand_depth = picker.opts.auto_expand_depth or 10
  new_state:expand_recursive(new_state.root_id, auto_expand_depth, function()
    vim.schedule(function()
      picker.list:set_target()
      picker:find()
    end)
  end)
end

--- Re-root the tree from the selected item.
---@param picker snacks.Picker
---@param item snacks.picker.Item
function M.reroot(picker, item)
  if not item then
    return
  end
  local state = finder.get_state(picker)
  if not state then
    return
  end
  local node = state.nodes[item.node_id]
  if not node then
    return
  end
  replace_state(picker, node.lsp_item, state.direction)
end

---@param picker snacks.Picker
---@param direction "incoming"|"outgoing"
function M._switch_direction(picker, direction)
  local state = finder.get_state(picker)
  if not state then
    return
  end
  local root = state.nodes[state.root_id]
  if not root then
    return
  end
  replace_state(picker, root.lsp_item, direction)
end

return M
