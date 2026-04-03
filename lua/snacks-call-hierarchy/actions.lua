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

  local target_node_id = item.node_id
  local target_top = picker.list.top

  state:toggle(item.node_id, function()
    vim.schedule(function()
      picker:find({
        refresh = true,
        on_done = function()
          local target_cursor
          for idx, refreshed in ipairs(picker:items()) do
            if refreshed.node_id == target_node_id then
              target_cursor = idx
              break
            end
          end
          if target_cursor then
            picker.list:view(target_cursor, target_top)
          end
        end,
      })
    end)
  end)
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

--- Toggle between incoming and outgoing direction, keeping the current root.
---@param picker snacks.Picker
function M.toggle_direction(picker)
  local state = finder.get_state(picker)
  if not state then
    return
  end
  local root = state.nodes[state.root_id]
  if not root then
    return
  end
  local other = state.direction == "incoming" and "outgoing" or "incoming"
  replace_state(picker, root.lsp_item, other)
end

--- Re-root at the selected item and show incoming calls.
---@param picker snacks.Picker
---@param item snacks.picker.Item
function M.reroot_incoming(picker, item)
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
  replace_state(picker, node.lsp_item, "incoming")
end

--- Re-root at the selected item and show outgoing calls.
---@param picker snacks.Picker
---@param item snacks.picker.Item
function M.reroot_outgoing(picker, item)
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
  replace_state(picker, node.lsp_item, "outgoing")
end

return M
