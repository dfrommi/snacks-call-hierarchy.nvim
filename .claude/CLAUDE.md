# snacks-call-hierarchy

Neovim plugin providing LSP call hierarchy as an expandable tree inside [snacks.nvim](https://github.com/folke/snacks.nvim) picker.

## Structure

```
lua/snacks-call-hierarchy/init.lua       -- setup(), registers picker sources into snacks with locked/user opts
lua/snacks-call-hierarchy/config.lua     -- Shared default values (max_depth, auto_expand_depth, max_open_requests)
lua/snacks-call-hierarchy/state.lua      -- Tree state: nodes, LSP fetching (fetch_children, expand_recursive, toggle, walk)
lua/snacks-call-hierarchy/finder.lua     -- Picker finder: first-run prepareCallHierarchy init + subsequent state walks; weak-keyed state registry
lua/snacks-call-hierarchy/format.lua     -- Formatter: tree indent + expand icon + kind icon + name + direction label (root) + file
lua/snacks-call-hierarchy/actions.lua    -- Actions: toggle (with focus restore), reroot_incoming, reroot_outgoing, toggle_direction
```

Reference plugins (in sibling directories, read-only, not modified):

- [meow.yarn.nvim](https://github.com/retran/meow.yarn.nvim) -- Reference for LSP call hierarchy protocol usage
- [snacks.nvim](https://github.com/folke/snacks.nvim) -- Reference for picker/tree APIs

## Architecture

Follows the **explorer pattern** from snacks.nvim:

1. External `State` object (per picker instance, weak-keyed in `finder._states`) holds the tree of LSP call hierarchy nodes
2. **First run**: finder captures `client` and `params` in the main loop (before async), then calls `textDocument/prepareCallHierarchy` via `vim.schedule`, creates State, and recursively expands to `auto_expand_depth`
3. **Subsequent runs**: finder walks existing state and emits a flat list of items with `parent` and `last` references for snacks' tree rendering
4. On toggle/reroot/switch-direction, state is mutated (or replaced) and `picker:find()` is re-run to refresh the display
5. All `client:request` calls in `state.lua` run on the main loop via `vim.schedule(callback)` after the response

## Key patterns

- **Node IDs**: Monotonic integers (not URI-based) so the same function can appear at multiple tree positions
- **Recursive expansion**: `State:expand_recursive()` fans out LSP requests in parallel using a pending counter; respects `max_depth`
- **Overload protection**: `max_open_requests` (default 100) caps parallel LSP requests during initial expansion; once hit, `open_capped` freezes all further fetches and a snacks/vim warning is shown
- **Node filtering**: `lsp_filter(item, ctx)` callback in config prunes non-matching branches as the tree is built; must return `true` to include a node (nil/false both exclude); root is always included; `FilterContext` carries `client`, `direction`
- **Focus preservation on toggle**: `actions.toggle` records `node_id` and `list.top` before re-find, then restores cursor and scroll in `on_done`
- **Sort by idx**: `sort = { fields = { "idx" } }` preserves DFS emission order during search instead of reordering by score
- **keep_parents / sort_empty**: Matcher options keep parent nodes visible when filtering and avoid reordering on empty query
- **last tracking**: Finder tracks the last child per parent so snacks draws correct tree branch connectors
- **Config options**: `max_depth` (default 20) caps LSP fetch depth; `auto_expand_depth` (default 10) controls initial expand depth; `max_open_requests` (default 100) caps parallel LSP requests on open
- **Keymappings**: `<CR>` open file, `za` toggle expand/collapse, `gi` reroot incoming, `go` reroot outgoing, `<leader><space>` toggle direction

## Testing

No automated tests. Test manually in Neovim 0.12 with an LSP server that supports `callHierarchyProvider`:

```vim
:lua require("snacks-call-hierarchy").setup()
:lua Snacks.picker.call_hierarchy_in()   -- incoming calls
:lua Snacks.picker.call_hierarchy_out()  -- outgoing calls
```
