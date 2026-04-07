local State = require("snacks-call-hierarchy.state")
local lsp_source = require("snacks.picker.source.lsp")

local M = {}

---@type table<snacks.Picker, snacks-call-hierarchy.State>
M._states = setmetatable({}, { __mode = "k" })

---@param picker snacks.Picker
---@return snacks-call-hierarchy.State?
function M.get_state(picker)
  return M._states[picker]
end

---@param picker snacks.Picker
---@param state snacks-call-hierarchy.State
function M.set_state(picker, state)
  M._states[picker] = state
end

---@param state snacks-call-hierarchy.State
---@param cb fun(item: snacks.picker.finder.Item)
---@param lsp_transform? fun(item: snacks.picker.finder.Item, lsp_item: lsp.CallHierarchyItem, client: vim.lsp.Client)
local function walk_and_emit(state, cb, lsp_transform)
  local nodes = state:walk()
  -- Map node_id -> emitted picker item for parent linking
  local items_by_id = {} ---@type table<integer, snacks.picker.finder.Item>
  -- Track last child per parent for tree rendering
  local last_child = {} ---@type table<integer, snacks.picker.finder.Item>

  -- First pass: create items
  local items = {} ---@type snacks.picker.finder.Item[]
  for _, node in ipairs(nodes) do
    local lsp_item = node.lsp_item
    local kind = lsp_source.symbol_kind(lsp_item.kind)
    local parent_item = node.parent_id and items_by_id[node.parent_id] or nil

    ---@type snacks.picker.finder.Item
    local item = {
      text = kind .. " " .. lsp_item.name,
      name = lsp_item.name,
      kind = kind,
      detail = lsp_item.detail,
      tree = true,
      parent = parent_item,
      last = true,
      node_id = node.id,
      expandable = node.children_ids == nil or #node.children_ids > 0,
      expanded = node.expanded,
      is_root = node.id == state.root_id,
    }

    local sel = lsp_item.selectionRange or lsp_item.range
    if sel and lsp_item.uri then
      lsp_source.add_loc(item, { uri = lsp_item.uri, range = sel }, state.client)
    end

    items_by_id[node.id] = item
    items[#items + 1] = item

    if lsp_transform then
      lsp_transform(item, lsp_item, state.client)
    end

    -- Track last child per parent
    if node.parent_id then
      -- Previous last child is no longer last
      if last_child[node.parent_id] then
        last_child[node.parent_id].last = false
      end
      last_child[node.parent_id] = item
    end
  end

  for _, item in ipairs(items) do
    cb(item)
  end
end

--- Create a finder for a given direction.
---@param direction "incoming"|"outgoing"
---@return snacks.picker.finder
function M.finder(direction)
  ---@param opts snacks.picker.Config
  ---@param ctx snacks.picker.finder.ctx
  return function(opts, ctx)
    local state = M._states[ctx.picker]

    if state then
      -- Subsequent runs: walk existing state
      ---@async
      return function(cb)
        walk_and_emit(state, cb, opts.lsp_transform)
      end
    end

    -- First run: prepare + fetch first level
    local buf = ctx.filter.current_buf
    local win = ctx.filter.current_win
    local max_depth = opts.max_depth or 20
    local auto_expand_depth = opts.auto_expand_depth or 10
    local max_open_requests = opts.max_open_requests or 100

    -- Capture client and params in the main loop (before entering async context)
    local clients = lsp_source.get_clients(buf, "textDocument/prepareCallHierarchy")
    if #clients == 0 then
      Snacks.notify.warn("No LSP client supports call hierarchy", { title = "Call Hierarchy" })
      return function() end
    end
    local client = clients[1]
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)

    ---@async
    return function(cb)
      local async = require("snacks.picker.util.async")
      local running = async.running()

      -- client:request must run on the main loop
      vim.schedule(function()
        client:request("textDocument/prepareCallHierarchy", params, function(err, result)
          if err or not result or #result == 0 then
            Snacks.notify.warn("No call hierarchy item at cursor", { title = "Call Hierarchy" })
            running:resume()
            return
          end

          local root_item = result[1]
          local new_state = State.new(client, root_item, direction, {
            max_depth = max_depth,
            max_open_requests = max_open_requests,
            lsp_filter = opts.lsp_filter,
          })
          M.set_state(ctx.picker, new_state)

          -- Recursively fetch and expand up to auto_expand_depth
          new_state:expand_recursive(new_state.root_id, auto_expand_depth, function()
            walk_and_emit(new_state, cb, opts.lsp_transform)
            running:resume()
          end)
        end)
      end)

      running:suspend()
    end
  end
end

M.incoming = M.finder("incoming")
M.outgoing = M.finder("outgoing")

return M
