# snacks-call-hierarchy

Neovim plugin providing LSP call hierarchy as an expandable tree inside [snacks.nvim](https://github.com/folke/snacks.nvim) picker.

## Structure

```
lua/snacks-call-hierarchy/init.lua       -- setup(), registers picker sources into snacks
lua/snacks-call-hierarchy/state.lua      -- Tree state: nodes, LSP fetching, expand/collapse
lua/snacks-call-hierarchy/finder.lua     -- Picker finder: walks state, emits flat items with parent links
lua/snacks-call-hierarchy/format.lua     -- Formatter: tree indent + expand icon + kind icon + name + file
lua/snacks-call-hierarchy/actions.lua    -- Actions: toggle, jump, reroot, switch direction
```

Reference plugins (in sibling directories, read-only, not modified):

- [meow.yarn.nvim](https://github.com/retran/meow.yarn.nvim) -- Reference for LSP call hierarchy protocol usage
- [snacks.nvim](https://github.com/folke/snacks.nvim) -- Reference for picker/tree APIs

## Architecture

Follows the **explorer pattern** from snacks.nvim:

1. External `State` object (per picker instance, weak-keyed) holds the tree of LSP call hierarchy nodes
2. Finder reads state and emits a flat list of items with `parent` references for snacks' tree rendering
3. On toggle/expand, state is mutated and `picker:find()` is re-run to refresh the display
4. LSP requests (`client:request`) must run on the main loop -- the finder captures params before entering the async context and wraps requests in `vim.schedule`

## Key patterns

- **Node IDs**: Monotonic integers (not URI-based) so the same function can appear at multiple tree positions
- **Recursive expansion**: `State:expand_recursive()` fans out LSP requests in parallel using a pending counter
- **Sort by idx**: `sort = { fields = { "idx" } }` preserves DFS emission order during search instead of reordering by score
- **keep_parents**: Matcher option ensures parent items stay visible when filtering

## Testing

No automated tests. Test manually in Neovim 0.12 with an LSP server that supports `callHierarchyProvider`:

```vim
:lua require("snacks-call-hierarchy").setup()
:lua Snacks.picker.call_hierarchy_in()   -- incoming calls
:lua Snacks.picker.call_hierarchy_out()  -- outgoing calls
```
