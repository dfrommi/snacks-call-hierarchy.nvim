---@class snacks-call-hierarchy.Node
---@field id integer
---@field lsp_item lsp.CallHierarchyItem
---@field parent_id integer?
---@field children_ids integer[]? nil = not fetched, {} = leaf or capped
---@field expanded boolean
---@field depth integer
---@field pending_fetch boolean?

---@class snacks-call-hierarchy.StateConfig
---@field max_depth? integer
---@field max_open_requests? integer
---@field lsp_filter? fun(item: snacks-call-hierarchy.FilterItem, ctx: snacks-call-hierarchy.FilterContext): boolean

---@class snacks-call-hierarchy.FilterItem : lsp.CallHierarchyItem
---@field path? string Absolute file path for `file://` URIs

---@class snacks-call-hierarchy.FilterContext
---@field client vim.lsp.Client
---@field direction "incoming"|"outgoing"

---@class snacks-call-hierarchy.State
---@field client vim.lsp.Client
---@field direction "incoming"|"outgoing"
---@field nodes table<integer, snacks-call-hierarchy.Node>
---@field root_id integer
---@field _next_id integer
---@field max_depth integer
---@field max_open_requests integer
---@field open_request_count integer
---@field open_capped boolean
---@field _warned_open_cap boolean
---@field lsp_filter? fun(item: snacks-call-hierarchy.FilterItem, ctx: snacks-call-hierarchy.FilterContext): boolean
local State = {}
State.__index = State

---@param client vim.lsp.Client
---@param root_item lsp.CallHierarchyItem
---@param direction "incoming"|"outgoing"
---@param opts? snacks-call-hierarchy.StateConfig
---@return snacks-call-hierarchy.State
function State.new(client, root_item, direction, opts)
  opts = opts or {}

  local self = setmetatable({}, State)
  self.client = client
  self.direction = direction
  self.nodes = {}
  self._next_id = 0
  self.max_depth = opts.max_depth or 20
  self.max_open_requests = opts.max_open_requests or 100
  self.open_request_count = 0
  self.open_capped = false
  self._warned_open_cap = false
  self.lsp_filter = opts.lsp_filter

  local root = self:_create_node(root_item, nil, 0)
  root.expanded = true
  self.root_id = root.id
  return self
end

---@param node snacks-call-hierarchy.Node
---@return boolean
function State:_is_fetch_blocked(node)
  return node.depth >= self.max_depth or self.open_capped
end

---@param lsp_item lsp.CallHierarchyItem
---@param is_root boolean
---@return boolean
function State:_matches_filter(lsp_item, is_root)
  if is_root or not self.lsp_filter then
    return true
  end

  ---@cast lsp_item snacks-call-hierarchy.FilterItem
  if lsp_item.uri and vim.startswith(lsp_item.uri, "file://") then
    lsp_item.path = vim.uri_to_fname(lsp_item.uri)
  else
    lsp_item.path = nil
  end

  return self.lsp_filter(lsp_item, {
    client = self.client,
    direction = self.direction,
  }) == true
end

---@param lsp_item lsp.CallHierarchyItem
---@param parent_id integer?
---@param depth integer
---@return snacks-call-hierarchy.Node
function State:_create_node(lsp_item, parent_id, depth)
  self._next_id = self._next_id + 1
  local node = {
    id = self._next_id,
    lsp_item = lsp_item,
    parent_id = parent_id,
    children_ids = nil,
    expanded = false,
    depth = depth,
    pending_fetch = false,
  }
  self.nodes[node.id] = node
  return node
end

function State:_notify_open_cap()
  if self._warned_open_cap then
    return
  end
  self._warned_open_cap = true

  local message = ("Stopped expanding call hierarchy after %d LSP requests."):format(self.max_open_requests)
  vim.schedule(function()
    if Snacks and Snacks.notify and Snacks.notify.warn then
      Snacks.notify.warn(message, { title = "Call Hierarchy" })
    else
      vim.notify(message, vim.log.levels.WARN, { title = "Call Hierarchy" })
    end
  end)
end

function State:_cap_open_frontier()
  self.open_capped = true

  for _, node in pairs(self.nodes) do
    if node.children_ids == nil and not node.pending_fetch then
      node.children_ids = {}
    end
  end

  self:_notify_open_cap()
end

---@param node_id integer
---@param callback fun()
---@param count_for_open_cap? boolean
function State:fetch_children(node_id, callback, count_for_open_cap)
  local node = self.nodes[node_id]
  if not node or node.children_ids then
    callback()
    return
  end

  if self:_is_fetch_blocked(node) then
    node.children_ids = {}
    callback()
    return
  end

  if count_for_open_cap then
    if self.open_request_count >= self.max_open_requests then
      self:_cap_open_frontier()
      node.children_ids = {}
      callback()
      return
    end
    self.open_request_count = self.open_request_count + 1
  end

  local method = self.direction == "incoming" and "callHierarchy/incomingCalls" or "callHierarchy/outgoingCalls"
  node.pending_fetch = true

  self.client:request(method, { item = node.lsp_item }, function(err, result)
    node.pending_fetch = false

    if err or not result then
      node.children_ids = {}
      vim.schedule(callback)
      return
    end

    node.children_ids = {}
    ---@param call lsp.CallHierarchyIncomingCall|lsp.CallHierarchyOutgoingCall
    for _, call in ipairs(result) do
      local child_item = self.direction == "incoming" and call.from or call.to
      if child_item and self:_matches_filter(child_item, false) then
        local child = self:_create_node(child_item, node_id, node.depth + 1)
        node.children_ids[#node.children_ids + 1] = child.id
      end
    end

    vim.schedule(function()
      if self.open_capped then
        self:_cap_open_frontier()
      end
      callback()
    end)
  end)
end

--- Calls callback once all recursive fetches are complete.
---@param node_id integer
---@param remaining_depth integer
---@param callback fun()
function State:expand_recursive(node_id, remaining_depth, callback)
  local node = self.nodes[node_id]
  if not node or remaining_depth <= 0 then
    callback()
    return
  end

  if node.children_ids then
    if #node.children_ids > 0 then
      node.expanded = true
      self:_expand_children(node, remaining_depth - 1, callback)
    else
      callback()
    end
    return
  end

  self:fetch_children(node_id, function()
    if node.children_ids and #node.children_ids > 0 then
      node.expanded = true
      self:_expand_children(node, remaining_depth - 1, callback)
    else
      callback()
    end
  end, true)
end

---@param node snacks-call-hierarchy.Node
---@param remaining_depth integer
---@param callback fun()
function State:_expand_children(node, remaining_depth, callback)
  if remaining_depth <= 0 or not node.children_ids or #node.children_ids == 0 then
    callback()
    return
  end

  local pending = #node.children_ids
  for _, child_id in ipairs(node.children_ids) do
    self:expand_recursive(child_id, remaining_depth, function()
      pending = pending - 1
      if pending == 0 then
        callback()
      end
    end)
  end
end

--- Toggle expand/collapse for a node.
--- If children haven't been fetched yet, fetches them first.
---@param node_id integer
---@param callback fun()
function State:toggle(node_id, callback)
  local node = self.nodes[node_id]
  if not node then
    callback()
    return
  end

  if node.children_ids == nil then
    if self:_is_fetch_blocked(node) then
      node.children_ids = {}
      callback()
      return
    end

    self:fetch_children(node_id, function()
      if #node.children_ids > 0 then
        node.expanded = true
      end
      callback()
    end)
    return
  end

  if #node.children_ids > 0 then
    node.expanded = not node.expanded
  end
  callback()
end

--- Depth-first walk over expanded nodes, yielding nodes in display order.
---@return snacks-call-hierarchy.Node[]
function State:walk()
  local result = {}

  local function visit(node_id)
    local node = self.nodes[node_id]
    if not node then
      return
    end
    result[#result + 1] = node
    if node.expanded and node.children_ids then
      for _, child_id in ipairs(node.children_ids) do
        visit(child_id)
      end
    end
  end

  visit(self.root_id)
  return result
end

return State
