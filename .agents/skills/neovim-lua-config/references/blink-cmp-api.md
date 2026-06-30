# blink.cmp configuration field map

Source: saghen/blink.cmp. Verified against v1.x schema.

## Top-level keys

```lua
opts = {
  keymap          = { preset = "default" },   -- or full keymap table
  appearance      = { nerd_font_variant = "mono" },
  sources         = { default = {...}, providers = {...} },
  completion      = { ... },
  signature       = { ... },
  fuzzy           = { implementation = "lua" },  -- or "prefer_rust"
}
```

## completion

```lua
completion = {
  documentation = {
    auto_show = false,           -- bool
    auto_show_delay_ms = 500,
    window = { border = "rounded" },
  },
  trigger = {
    show_on_blocked_trigger_characters = {},
  },
  menu = {
    draw = { ... },
  },
}
```

## signature

```lua
signature = {
  enabled = true,
  window = {
    show_documentation = false,  -- CORRECT field name
    border = "rounded",
  },
}
```

INVALID (causes "Unexpected field" warning at startup):
```lua
signature = { documentation = { auto_show = false } }   -- WRONG
```

## sources.providers (ripgrep example)

```lua
sources = {
  default = { "lsp", "path", "snippets", "buffer" },
  providers = {
    ripgrep = {
      module = "blink-ripgrep",
      name   = "Ripgrep",
      score_offset = -3,
    },
  },
},
```
