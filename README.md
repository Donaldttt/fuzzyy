# Fuzzyy

A fuzzy picker for files, strings, help documents and many other things.

It ultilizes vim's native matchfuzzypos function and popup window feature.

[demo](https://github.com/Donaldttt/resources/blob/main/fuzzyy/demo.gif)

## Install

Any plugin manager will work.

For vim-plug
```
Plug 'Donaldttt/fuzzyy'
```

## Commands

| Command       | Description                    | Default Keymap |
| ---           | ---                            |   ---             |
| FuzzyGrep     | grep string in project         | \<leader>fr     |
| FuzzyFiles    | search files in project        | \<leader>ff     |
| FuzzyHelps    | search :help documents         | \<leader>fd     |
| FuzzyColors   | search installed colorscheme   | \<leader>fc     |
| FuzzyInBuffer | search lines in current buffer | \<leader>fb     |
| FuzzyCommands | search commands                | \<leader>fi     |

FuzzyGrep requires any of grep, ag or rg command.

FuzzyFiles uses find command in unix (if not found it will use vim's glob function,
 which is blocking) or powershell's Get-ChildItem in windows.

## Default Keymaps

you can set `g:enable_fuzzyy_keymaps = 0` to disable default keymaps

```
nnoremap <silent> <leader>fb :FuzzyInBuffer<CR>
nnoremap <silent> <leader>fc :FuzzyColors<CR>
nnoremap <silent> <leader>fd :FuzzyHelps<CR>
nnoremap <silent> <leader>ff :FuzzyFiles<CR>
nnoremap <silent> <leader>fi :FuzzyCommands<CR>
nnoremap <silent> <leader>fr :FuzzyGrep<CR>
```

## API

This plugin also exposes API to build your custom picker.
If you need examples please refer to /autoload/fuzzy/colors.vim, helps.vim etc.

vim9
```vim9script
vim9script

import autoload 'utils/selector.vim'

# This function spawn a popup picker for user to select an item from a list.
# params:
#   - list: list of string to be selected. can be empty at init state
#   - opts: dict of options
#       - comfirm_cb: (function reference) callback to be called when user select an item.
#           comfirm_cb(menu_wid, result). result is a list like ['selected item']
#       - preview_cb: (function reference) callback to be called when user move cursor on an item.
#           preview_cb(menu_wid, result). result is a list like ['selected item', opts]
#       - input_cb: (function reference) callback to be called when user input something. If input_cb
#           is not set, then the input will be used as the pattern to filter the
#           list. If input_cb is set, then the input will be passed to given callback.
#           input_cb(menu_wid, result). the second argument result is a list ['input string', opts]
#       - preview: wheather to show preview window, default 1
#       - width: width of the popup window, default 80. If preview is enabled,
#           then width is the width of the total layout.
#       - xoffset: x offset of the popup window. The popup window is centered
#           by default.
#       - scrollbar: wheather to show scrollbar in the menu window.
#       - preview_ratio: ratio of the preview window. default 0.5
#       - dropdown: use dropdown menu
# return:
#   - a list [menu_wid, prompt_wid]
#   - if has preview = 1, then return [menu_wid, prompt_wid, preview_wid]
selector.Start(...)
```

vim8

```vimscript
import autoload 'utils/selector.vim'

s:selector.Start(...)
```

