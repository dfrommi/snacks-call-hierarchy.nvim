# snacks-call-hierarchy.nvim

LSP call hierarchy as an expandable tree inside a [snacks.nvim](https://github.com/folke/snacks.nvim) picker.

Browse incoming and outgoing call trees, expand nodes on demand, re-root from any entry, and stay inside the usual snacks picker workflow.

## Requirements

- Neovim >= 0.12
- [snacks.nvim](https://github.com/folke/snacks.nvim) with the `picker` module enabled
- An LSP server that supports `callHierarchyProvider` (e.g. lua-language-server, clangd, rust-analyzer, gopls, …)

## Installation

### vim.pack.add (Neovim built-in)

```lua
-- Add to your init.lua before snacks.nvim is configured
vim.pack.add("https://github.com/dfrommi/snacks-call-hierarchy.nvim")

-- Then call setup() once, after snacks is set up
require("snacks-call-hierarchy").setup()
```

### lazy.nvim

```lua
{
  "dfrommi/snacks-call-hierarchy.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {},
}
```

`opts` is forwarded to `setup()` automatically. Omit it to use defaults.

## Configuration

Default configuration:

```lua
require("snacks-call-hierarchy").setup({
  max_depth = 20,         -- maximum depth fetched from LSP
  auto_expand_depth = 10, -- depth expanded automatically on open
  max_open_requests = 100, -- maximum child LSP requests during initial expansion
})
```

This is the default config used when you call `setup()` without overrides.

`setup()` also accepts regular snacks picker options such as `layout`, `preview`, or window settings. This plugin applies them as defaults for both call hierarchy sources.

If initial expansion trips the request cap, the picker keeps the partial tree that has already loaded, shows a warning, and stops further fetching for that picker state.

Example with `lsp_filter` — filter for production code scope (exclude test sources and dependencies):

```lua
require("snacks-call-hierarchy").setup({
  lsp_filter = function(item, ctx)
    if ctx.client.name == "jdtls" then
      return item.path and item.path:find("/src/main/", 1, true) ~= nil
    end
    if ctx.client.name == "rust-analyzer" then
      return item.path
        and item.path:find("/.cargo/", 1, true) == nil
        and item.path:find("/.rustup/", 1, true) == nil
    end
    return item.path ~= nil
  end,
})
```

`lsp_filter` is applied while expanding the call hierarchy. Returning `true` includes a node; anything else (including `nil`) prunes that branch entirely, so excluded nodes are neither shown nor traversed further. For `file://` URIs, the item passed to the filter also includes `item.path`. The initial root item is always included automatically.

## Usage

Open the picker from the cursor position:

```lua
Snacks.picker.call_hierarchy_in()   -- incoming calls (who calls this?)
Snacks.picker.call_hierarchy_out()  -- outgoing calls (what does this call?)
```

Map to keys in your config, e.g.:

```lua
vim.keymap.set("n", "<leader>ci", function() Snacks.picker.call_hierarchy_in() end,  { desc = "Incoming call hierarchy" })
vim.keymap.set("n", "<leader>co", function() Snacks.picker.call_hierarchy_out() end, { desc = "Outgoing call hierarchy" })
```

The root entry is annotated with `[Incoming]` or `[Outgoing]` so the current direction stays visible after re-rooting.

### Actions

This plugin registers the following actions into the picker. Bind them however you like via `win.input.keys` / `win.list.keys` in `setup()` or at call-site:

| Action | Description |
|---|---|
| `call_hierarchy_toggle_expanded` | Expand or collapse the selected node |
| `call_hierarchy_incoming` | Re-root at the selected item and show incoming calls |
| `call_hierarchy_outgoing` | Re-root at the selected item and show outgoing calls |
| `call_hierarchy_toggle_direction` | Toggle incoming/outgoing direction for the current root |

Example keybinding configuration:

```lua
local keys = {
  ["<CR>"]            = { "confirm",                           desc = "Open file" },
  ["za"]              = { "call_hierarchy_toggle_expanded",    desc = "Toggle expand/collapse" },
  ["gi"]              = { "call_hierarchy_incoming",           desc = "Re-root: incoming calls" },
  ["go"]              = { "call_hierarchy_outgoing",           desc = "Re-root: outgoing calls" },
  ["<leader><space>"] = { "call_hierarchy_toggle_direction",   desc = "Toggle direction" },
}

require("snacks-call-hierarchy").setup({
  win = {
    input = { keys = keys },
    list  = { keys = keys },
  },
})
```

Default snacks picker mappings still apply unless you override them.

## Recipes

### Export call sites to the quickfix list

Open the call hierarchy, then use `<Tab>` to multi-select the entries you care about and press `<Ctrl-q>` to send them to the quickfix list. From there, `:cnext`/`:cprev` lets you visit every call site systematically.

### Trace enclosed use-case

Open incoming calls on the function you are investigating. Navigate up the tree to find the entry point that represents the use-case. Press `go` (`call_hierarchy_outgoing`) on that node to re-root with outgoing calls. The tree now shows the full execution context of that specific use-case.

## Picker options

The picker is built on [snacks.nvim](https://github.com/folke/snacks.nvim)'s picker. You can pass snacks picker options through `setup()` as global defaults, or at call-site for one-off overrides.

```lua
-- Global defaults via setup()
require("snacks-call-hierarchy").setup({
  max_depth = 20,
  max_open_requests = 100,
  layout = "ivy",   -- any snacks picker option
  preview = false,
})

-- Per-call overrides (snacks merges these on top of the source config)
Snacks.picker.call_hierarchy_in({ title = "Who calls this?" })
Snacks.picker.call_hierarchy_out({ layout = "vertical" })
```

### Options that cannot be overridden

These are controlled by the plugin and should be treated as internal:

| Option | Why |
|---|---|
| `finder` | Chosen automatically from the requested direction |
| `format` | Uses a custom formatter for tree structure and labels |
| `tree` | Required for tree rendering |
| `sort` | Fixed to `idx` to preserve depth-first tree order |
| `max_depth` | Consumed by the plugin before the picker config is built |
| `auto_expand_depth` | Consumed by the plugin before the picker config is built |
| `max_open_requests` | Consumed by the plugin before the picker config is built |
| `matcher.keep_parents` | Keeps parent nodes visible while filtering |
| `matcher.sort_empty` | Prevents reordering when the query is empty |

## Credits

LSP call hierarchy protocol usage based on [meow.yarn.nvim](https://github.com/retran/meow.yarn.nvim).
