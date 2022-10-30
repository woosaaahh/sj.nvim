<!-- 
vim: expandtab tabstop=2 
-->

- [Requirements](#requirements)
- [Usage](#usage)
- [Configuration](#configuration)
- [Why this plugin ?](#why)

## SJ - Search and Jump

Search based navigation combined with quick jump features.

<p align="center">
  Demo<br>
  <img src="https://user-images.githubusercontent.com/111681540/197946515-e2818592-bf3d-439a-99f3-8c9eabd2fbce.gif">
</p>

<p align="center">
  Screenshots<br>
  <img src="https://user-images.githubusercontent.com/111681540/197934569-999dba0d-bbd2-4a9b-8be5-997207ac0cc0.png">
  <img src="https://user-images.githubusercontent.com/111681540/197934582-b860c767-64f4-4b44-b38b-007afb4e8cc1.png">
</p>

### Requirements

Only [Neovim 0.8+](https://github.com/neovim/neovim/releases) is required, nothing more.

### Usage

The main goal of this plugin is to quickly jump to any characters using a search pattern.

By default, the search is made forward and only in visible lines of the current buffer.

To start using SJ, you can add the lines below in your configuration for Neovim.

```lua
local sj = require("sj")
sj.setup()

vim.keymap.set("n", "s", sj.run)
vim.keymap.set("n", "<A-,>", sj.prev_match)
vim.keymap.set("n", "<A-;>", sj.next_match)
vim.keymap.set("n", "<localleader>s", sj.redo)
``` 

As soon as you use the keymap assigned to `sj.run()` and start typing the pattern :

- the highlights in the buffer will change ;
- all matches will be highlighted and will have a label assigned to them ;
- the pattern is displayed in the command line.

While searching, you can use the keymaps below :

| Keymap              | Description                                                      |
|---------------------|------------------------------------------------------------------|
| `<Escape>`          | cancel the search                                                |
| `<Enter>`           | jump to the focused match                                        |
| `:a`, `:b`, `:c`    | jump to the the match with the label `a`, `b` or `c`             |
| `<A-,>`, `<A-;>`    | focus the previous or next match                                 |
| `<C-p>`, `<C-n>`    | select the previous or next pattern                              |
| `<BS>`              | delete the previous character                                    |
| `<C-w>`             | delete the previous word                                         |
| `<C-u>`             | delete the whole pattern                                         |
| `<A-BS>`            | restore the pattern to the last version having matches           |
| `<A-q>`             | send the search results to the quickfix list                     |

After the search, you can call `sj.prev_match()` and `sj.next_match()` to jump on the
previous/next match or `sj.redo()` to redo a search using the last pattern.

**Notes** :

- When there are no matches, the pattern in the cmdline will have a different color ;
- When you use `max_pattern_length` and you reach that length limit, the labels color will
  change to indicate that the next key should be for a label and not for the pattern.
  (When reaching this limit, no need to type `:` before the label)

### Configuration

Here is the default configuration :

```lua
local config = {
  auto_jump = false, -- if true, automatically jump on the sole match
  forward_search = true, -- if true, the search will be done from top to bottom
  highlights_timeout = 0, -- if > 0, wait for 'updatetime' + N ms to clear hightlights (sj.prev_match/sj.next_match)
  max_pattern_length = 0, -- if > 0, wait for a label after N characters
  multi_windows = false, -- if true, the search will be done in all visible lines of all windows
  pattern_type = "vim", -- how to interpret the pattern (lua_plain, lua, vim, vim_very_magic)
  preserve_highlights = true, -- if true, create an autocmd to preserve highlights when switching colorscheme
  prompt_prefix = "", -- if set, the string will be used as a prefix in the command line
  relative_labels = false, -- if true, labels are ordered from the cursor position, not from the top of the buffer
  search_scope = "visible_lines", -- (current_line, visible_lines_above, visible_lines_below, visible_lines, buffer)
  select_window = false, -- if true, ask for a window to jump to before starting the search
  separator = ":", -- character used to split the user input in <pattern> and <label>
  update_search_register = false, -- if true, update the search register with the last used pattern
  use_last_pattern = false, -- if true, reuse the last pattern for next calls
  use_overlay = true, -- if true, apply an overlay to better identify labels and matches
  wrap_jumps = vim.o.wrapscan, -- if true, wrap the jumps when focusing previous or next label

  --- keymaps used during the search
  keymaps = { 
    cancel = "<Esc>", -- cancel the search
    validate = "<CR>", -- jump to the focused match
    prev_match = "<A-,>", -- focus the previous match
    next_match = "<A-;>", -- focus the next match
    prev_pattern = "<C-p>", -- select the previous pattern while searching
    next_pattern = "<C-n>", -- select the next pattern while searching
    ---
    delete_prev_char = "<BS>", -- delete the previous character
    delete_prev_word = "<C-w>", -- delete the previous word
    delete_pattern = "<C-u>", -- delete the whole pattern
    restore_pattern = "<A-BS>", -- restore the pattern to the last version having matches
    ---
    send_to_qflist = "<A-q>", --- send the search results to the quickfix list
  },

  --- labels used for each matches. (one-character strings only)
  -- stylua: ignore
  labels = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", ";", "!",
  },
}
```

and here is a configuration sample :

**DISCLAIMER** : This plugin is not intended to replace the native functions of Neovim.
<br>I do not recommend adding keymaps that replaces `/, ?, f/F, t/T...`.

```lua
local sj = require("sj")
local sj_cache = require("sj.cache")

--- Configuration ------------------------------------------------------------------------

sj.setup({
  prompt_prefix = "/",

  -- stylua: ignore
  highlights = {
    SjFocusedLabel = { bold = false, italic = false, fg = "#FFFFFF", bg = "#C000C0", },
    SjLabel =        { bold = true , italic = false, fg = "#000000", bg = "#5AA5DE", },
    SjLimitReached = { bold = true , italic = false, fg = "#000000", bg = "#DE945A", },
    SjMatches =      { bold = false, italic = false, fg = "#DDDDDD", bg = "#005080", },
    SjNoMatches =    { bold = false, italic = false, fg = "#DE945A",                 },
    SjOverlay =      { bold = false, italic = false, fg = "#345576",                 },
  },

  keymaps = {
    send_to_qflist = "<C-q>", --- send search result to the quickfix list
  },
})

--- Keymaps ------------------------------------------------------------------------------

vim.keymap.set("n", "!", function()
  sj.run({ select_window = true })
end)

vim.keymap.set("n", "<A-!>", function()
  sj.select_window()
end)

--- visible lines -------------------------------------

vim.keymap.set({ "n", "o", "x" }, "S", function()
  vim.fn.setpos("''", vim.fn.getpos("."))
  sj.run({
    forward_search = false,
  })
end)

vim.keymap.set({ "n", "o", "x" }, "s", function()
  vim.fn.setpos("''", vim.fn.getpos("."))
  sj.run()
end)

vim.keymap.set({ "n", "o", "x" }, "gs", function()
  vim.fn.setpos("''", vim.fn.getpos("."))
  sj.run({ multi_windows = true })
end)

vim.keymap.set("n", "<localleader>c", function()
  sj.run({
    max_pattern_length = 1,
    pattern_type = "lua_plain",
  })
end)

--- buffer --------------------------------------------

vim.keymap.set("n", "<A-s>", function()
  vim.fn.setpos("''", vim.fn.getpos("."))
  sj.run({
    forward_search = false,
    search_scope = "buffer",
    update_search_register = true,
  })
end)

vim.keymap.set("n", "<A-S>", function()
  vim.fn.setpos("''", vim.fn.getpos("."))
  sj.run({
    search_scope = "buffer",
    update_search_register = true,
  })
end)

--- current line --------------------------------------

vim.keymap.set({ "n", "o", "x" }, "<localleader>l", function()
  sj.run({
    auto_jump = true,
    max_pattern_length = 1,
    pattern_type = "lua_plain",
    search_scope = "current_line",
    use_overlay = false,
  })
end)

--- prev/next match -----------------------------------

vim.keymap.set("n", "<A-,>", function()
  sj.prev_match()
  if sj_cache.options.search_scope:match("^buffer") then
    vim.cmd("normal! zzzv")
  end
end)

vim.keymap.set("n", "<A-;>", function()
  sj.next_match()
  if sj_cache.options.search_scope:match("^buffer") then
    vim.cmd("normal! zzzv")
  end
end)

--- redo ----------------------------------------------

vim.keymap.set("n", "<localleader>a", function()
  local relative_labels = sj_cache.options.relative_labels
  sj.redo({
    relative_labels = false,
    max_pattern_length = 1,
  })
  sj_cache.options.relative_labels = relative_labels
end)

vim.keymap.set("n", "<localleader>s", function()
  sj.redo({
    relative_labels = true,
    max_pattern_length = 1,
  })
end)
```  

**DISCLAIMER** : This plugin is not intended to replace the native functions of Neovim. 
<br>I do not recommend adding keymaps that replaces `/, ?, f/F, t/T...`.

## Why

Why this plugin ?! Well, let me explain ! :smiley:

Using vertical/horizontal navigation with `<count>k/j`, `:<count><CR>`,
`H/M/L/f/F/t/T/,/;b/e/w^/$`, is a very good way to navigate. But with the keyboards I use,
I have to press the `<Shift>` key to type numbers and some of them are a bit to far for my
fingers. Once on the good line, I have to repeat pressing some horizontal movement keys
too much.

When navigating in a buffer, I often find the search based navigation to be easier, faster
and more precise. But if there are too many matches, I have to repeat pressing a key to
cycle between the matches. By adding jump features with labels, I can quickly jump to the
match I want.

For me, one small caveat of the 'jump plugins', is that they generate the labels or 'hint
keys' based on the cursor position. That is understandable and efficient but within the
same buffer area, it means that you can have different labels for the same pattern or
position which make the keys sequence for a jump less predictables. Also, in some
contexts, you don't know if you'll have to use a 1, 2 or 3 characters for the label.

By using a search pattern with a 1-character label, you already know all the keys except
one character for the label.
