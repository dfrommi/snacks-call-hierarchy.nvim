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

Example with `lsp_filter`:

```lua
require("snacks-call-hierarchy").setup({
  max_depth = 20,
  auto_expand_depth = 10,
  max_open_requests = 100,
  lsp_filter = function(item)
    return item.path and item.path:find("/src/main/", 1, true) ~= nil
  end,
})
```

`lsp_filter` is applied while expanding the call hierarchy. Returning `false` prunes that branch entirely, so excluded nodes are neither shown nor traversed further. For `file://` URIs, the item passed to the filter also includes `item.path`. The initial root item is always included automatically.

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

### Picker keybindings

Added by this plugin for both the picker list and the input window:

| Key | Action |
|---|---|
| `<CR>` | Open the selected location |
| `<leader><space>` | Toggle incoming/outgoing direction for the current root |
| `za` | Expand or collapse the selected node |
| `gi` | Re-root at the selected item and show incoming calls |
| `go` | Re-root at the selected item and show outgoing calls |

Other default snacks picker mappings still apply unless you change them in snacks itself.

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

The plugin also installs its own keymaps into `win.input.keys` and `win.list.keys` for `<CR>`, `<leader><space>`, `za`, `gi`, and `go`. You can still add other keys alongside them.

## Credits

LSP call hierarchy protocol usage based on [meow.yarn.nvim](https://github.com/retran/meow.yarn.nvim).
