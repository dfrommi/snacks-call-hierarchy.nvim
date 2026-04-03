# snacks-call-hierarchy.nvim

LSP call hierarchy as an expandable tree inside a [snacks.nvim](https://github.com/folke/snacks.nvim) picker.

Navigate incoming and outgoing call trees, expand nodes on demand, and switch direction — all inside the familiar snacks picker UI.

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

```lua
require("snacks-call-hierarchy").setup({
  max_depth        = 20,  -- maximum depth fetched from LSP
  auto_expand_depth = 10, -- depth expanded automatically on open
})
```

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

### Picker keybindings

Added by this plugin (work in both the list and the input field's normal mode):

| Key    | Action                              |
|--------|-------------------------------------|
| `za`   | Expand/collapse node                |
| `gi`   | Switch to incoming calls            |
| `go`   | Switch to outgoing calls            |
| `gr`   | Re-root tree from selected node     |

Inherited from snacks.nvim defaults (remapping them there will affect this picker too):

| Key      | Default action                                         |
|----------|--------------------------------------------------------|
| `<CR>`   | Jump to location                                       |
| `<Tab>`  | Toggle selection and move to next item                 |
| `<C-q>`  | Send selected items to quickfix (all if none selected) |

## Picker options

The picker is powered by [snacks.nvim](https://github.com/folke/snacks.nvim)'s picker. Any option accepted by snacks picker can be passed to `setup()` as a global default, or directly at call-site for one-off overrides.

```lua
-- Global defaults via setup()
require("snacks-call-hierarchy").setup({
  max_depth = 20,
  layout = "ivy",   -- any snacks picker option
  preview = false,
})

-- Per-call overrides (snacks merges these on top of the source config)
Snacks.picker.call_hierarchy_in({ title = "Who calls this?" })
Snacks.picker.call_hierarchy_out({ layout = "vertical" })
```

### Options that cannot be overridden

These are locked by the internal tree mechanics and will be ignored if passed:

| Option | Reason |
|--------|--------|
| `finder` | Set automatically based on direction (incoming/outgoing) |
| `format` | Custom tree renderer required for indent and icons |
| `tree` | Must be `true` for tree layout |
| `sort` | Must sort by `idx` to preserve depth-first tree order |
| `matcher.keep_parents` | Required to keep parent nodes visible when filtering |
| `matcher.sort_empty` | Required to avoid reordering when the search query is empty |
| `win.*.keys` for `za` `gi` `go` `gr` | Plugin keybindings; you may still add your own keys |

## Credits

LSP call hierarchy protocol usage based on [meow.yarn.nvim](https://github.com/retran/meow.yarn.nvim).
