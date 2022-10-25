- [Requirements](#requirements)
- [Usage](#usage)
- [Configuration](#configuration)
- [Why this plugin ?](#why)

# SJ - Search and Jump

Search based navigation combined with quick jump features.

![03](https://user-images.githubusercontent.com/111681540/192203643-77892c37-644d-4285-af3f-7d3c7a8c94a7.png)
![04](https://user-images.githubusercontent.com/111681540/192203653-30327d73-a43e-4445-b4de-d9504db677bd.png)


## Requirements

To use this plugin, you need :

- to have [Neovim](https://github.com/neovim/neovim)
  ['nightly'](https://github.com/neovim/neovim/releases/tag/nightly) version installed ;
- to add `woosaaahh/sj.nvim` in your plugin manager configuration.

Here are some examples :

- [vim-plug](https://github.com/junegunn/vim-plug) `Plug 'woosaaahh/sj.nvim'` ;
- [packer.nvim](https://github.com/wbthomason/packer.nvim) `use 'woosaaahh/sj.nvim'` ;
- [paq-nvim](https://github.com/savq/paq-nvim) `"woosaaahh/sj.nvim"`.

## Usage

The goal of this plugin is to quickly navigate to any characters/words that are visible in
the current buffer and quickly jump to any match.

To do so, use a keymap ([Configuration](#configuration)) and type a pattern.

As soon as you use the keymap and start typing the pattern :

- the highights in the buffer will change ;
- all matches will be highlighted and will have a label assigned to them ;
- the current pattern is displayed in the command line.

Now you can :

- jump to the first match by pressing the `<Enter>` key or `<Control-j>` ;
- jump to any matches by typing `:`, then the label assigned to the match ;
- delete previous characters by pressing `<Backspace>` or `<Control-h>` ;
- delete the pattern by pressing `<Control-u>` ;
- restore last matching pattern by pressing `<Alt-Backspace>` ;
- jump to previous or next match while searching by pressing `<Alt-,>` or `<Alt-;>` ;
- send search results to the `qflist` by pressing `<Alt-q>` or `<Control-q>` ;
- cancel everything by pressing the `<Escape>` key.

Notes :

- There is an `auto_jump` feature which will automatically jump to a match if it is the
  only one in the visible area. You will not have to type `<Enter>` or `:` and a label ;
- If there are no matches for the current pattern, the pattern in the command line will be
  displayed in a different color ;
- When you use `max_pattern_length` and you reach that length limit, the labels color will change to indicate that next key should be for the label and not for the pattern.
- After a search, you can jump to the previous or the next match by using
  `require("sj").prev_match()` and `require("sj").next_match()`. Note that the jumps will
  be relative to the cursor position.
	
**DISCLAIMER** : This plugin is not intended to replace the native functions of Neovim. I do not recommend adding keymaps that replaces `/, ?, f/F, t/T...`.

## Configuration

Here is the default configuration :

```lua
local config = {
	auto_jump = false, -- if true, automatically jump on the sole match
	forward_search = true, -- if true, search will be done from top to bottom
	highlights_timeout = 0, -- if > 0, wait for 'updatetime' + N ms to clear hightlights (sj.prev_match/sj.next_match)
	max_pattern_length = 0, -- if > 0, wait for a label after N characters
	pattern_type = "vim", -- how to interpret the pattern (lua_plain, lua, vim, vim_very_magic)
	preserve_highlights = true, -- if true, create an autocmd to preserve highlights when switching colorscheme
	prompt_prefix = "", -- if set, the string will be used as prefix in the command line
	relative_labels = false, -- if true, labels are ordered from cursor position, not from the top of the buffer
	search_scope = "visible_lines", -- (current_line, visible_lines_above, visible_lines_below, visible_lines, buffer)
	separator = ":", -- character used to split the user input in <pattern> and <label>
	update_search_register = false, -- if true, update the search register with the last used pattern
	use_last_pattern = false, -- if true, reuse the last pattern for next calls
	use_overlay = true, -- if true, apply an overlay to better identify labels and matches
	wrap_jumps = vim.o.wrapscan, -- if true, wrap the jumps when focusing previous or next label

	keymaps = {
		cancel = "<Esc>", -- cancel the search
		validate = "<CR>", -- jump to the current focused label and match
		prev_match = "<A-,>", -- focus the previous label and match
		next_match = "<A-;>", -- focus the next label and match
		---
		delete_prev_char = "<BS>", -- delete previous character
		delete_prev_word = "<C-w>", -- delete previous word
		delete_pattern = "<C-u>", -- delete the whole pattern
		restore_pattern = "<A-BS>", -- restore the pattern to the last matching version
		---
		send_to_qflist = "<A-q>", --- send search result to the quickfix list
	},

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

```lua
local colors = {
	black = "#000000",
	light_gray = "#DDDDDD",
	white = "#FFFFFF",

	blue = "#5AA5DE",
	dark_blue = "#345576",
	darker_blue = "#005080",

	green = "#40BC60",
	magenta = "#C000C0",
	orange = "#DE945A",
}

local sj = require("sj")
sj.setup({
	pattern_type = "vim_very_magic",
	prompt_prefix = "Pattern ? ",
	search_scope = "visible_lines",

	highlights = {
		SjFocusedLabel = { fg = colors.white, bg = colors.magenta, bold = false, italic = false },
		SjLabel = { fg = colors.black, bg = colors.blue, bold = true, italic = false },
		SjLimitReached = { fg = colors.black, bg = colors.orange, bold = true, italic = false },
		SjMatches = { fg = colors.light_gray, bg = colors.darker_blue, bold = false, italic = false },
		SjNoMatches = { fg = colors.orange, bold = false, italic = false },
		SjOverlay = { fg = colors.dark_blue, bold = false, italic = false },
	},

	keymaps = {
		prev_match = "<C-p>", -- focus the previous label and match
		next_match = "<C-n>", -- focus the next label and match
		---
		send_to_qflist = "<C-q>", --- send search result to the quickfix list
	},
})

vim.keymap.set("n", "s", function()
	sj.run({ wrap_jumps = true })
end)

vim.keymap.set("n", "S", function()
	sj.run({
		forward_search = false,
		wrap_jumps = true,
	})
end)

vim.keymap.set("n", "<A-,>", sj.prev_match)
vim.keymap.set("n", "<A-;>", sj.next_match)

vim.keymap.set("n", "gs", function()
	sj.run({ 
		search_scope = "buffer", 
		update_search_register = true,
    })
end)

vim.keymap.set({ "n", "o", "v" }, "<localleader>c", function()
	sj.run({ max_pattern_length = 1 })
end)

vim.keymap.set({ "n", "o", "v" }, "<localleader>l", function()
	sj.run({
		auto_jump = true,
		max_pattern_length = 1,
		pattern_type = "lua_plain",
		search_scope = "current_line",
		use_overlay = false,
	})
end)

vim.keymap.set({ "n", "o", "v" }, "<localleader>s", function()
	sj.redo({ max_pattern_length = 1 })
end)

vim.keymap.set({ "n", "o", "v" }, "<localleader>x", sj.redo)
```	

**DISCLAIMER** : This plugin is not intended to replace the native functions of Neovim. I do not recommend adding keymaps that replaces `/, ?, f/F, t/T...`.

## Why

Why this plugin ?! Well, let me explain ! :smiley:

Using vertical/horizontal navigation with `<count>k/j`, `:<count><CR>`, `H/M/L/f/F/t/T/,/;b/e/w^/$`,
is a very good way to navigate. But with the keyboards I use, I have to press the
`<Shift>` key to type numbers and some of them are a bit to far for my fingers.
Once on the good line, I have to repeat pressing some vertical movement keys too much.

When navigating in a buffer, I often find the search based navigation to be easier, faster
and more precise. But if there are too many matches, I have to repeat pressing a key to
cycle between the matches. By adding jump features with labels, I can quickly jump to the
match I want.

For me, one small caveat of the 'jump plugins', is that they generate the labels or 'hint
keys' based on the cursor position. That is understandable and efficient but within the
same buffer area, it means that you can have different labels for the same pattern/position
which make the keys sequence for a jump less predictables. Also, in some
contexts, you don't know if you'll have to use a 1, 2 or 3 characters for the label.

By using a search pattern with a 1 character label, you can narrow the list of labels and
you already know all the keys except one character for the label.
