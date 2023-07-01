# Fuzzyy

A fuzzy picker for files, strings, help documents and many other things.

It ultilizes vim's native matchfuzzypos function and popup window feature.

## Screenshots

![screenshot](https://github.com/Donaldttt/resources/blob/main/fuzzyy/demo.png)

[gif](https://github.com/Donaldttt/resources/blob/main/fuzzyy/demo.gif)

## Requirements

- vim > 0.9
    - The maintained version is written in vim9, but it also has a vim8 branch for older vim.
- any of grep, ag or rg
- find
- [vim-devicons](https://github.com/ryanoasis/vim-devicons) (optional)

## Install

Any plugin manager will work.

For vim-plug
```vim
Plug 'Donaldttt/fuzzyy'
```

## Commands

| Command         | Description                    | Default Keymap |
| ---             | ---                            | ---            |
| FuzzyGrep       | grep string in project         | \<leader>fr    |
| FuzzyFiles      | search files in project        | \<leader>ff    |
| FuzzyHelps      | search :help documents         | \<leader>fd    |
| FuzzyColors     | search installed colorscheme   | \<leader>fc    |
| FuzzyInBuffer   | search lines in current buffer | \<leader>fb    |
| FuzzyCommands   | search commands                | \<leader>fi    |
| FuzzyBuffers    | search opened buffers          | \<leader>ft    |
| FuzzyHighlights | search highlights              | \<leader>fh    |

FuzzyGrep requires any of grep, ag or rg command.

FuzzyFiles uses find command in unix (if not found it will use vim's glob function,
 which is blocking) or powershell's Get-ChildItem in windows.
(if [fd](https://github.com/sharkdp/fd) is installed, it will be used)

## Navigation

Arrow keys or `ctrl + p`/ `ctrl + n` moves up/down the menu

`ctrl + u`/`ctrl + d` moves up/down the buffer in preview window

you can set `g:fuzzyy_keymaps` to change these defaults.

### Command Specific keymaps
- FuzzyHighlights
    - `ctrl + k` toggle white preview background color
    - `Enter` will copy selected highlight

## Default Keymaps

you can set `g:enable_fuzzyy_keymaps = 0` to disable default keymaps

```vim
nnoremap <silent> <leader>fb :FuzzyInBuffer<CR>
nnoremap <silent> <leader>fc :FuzzyColors<CR>
nnoremap <silent> <leader>fd :FuzzyHelps<CR>
nnoremap <silent> <leader>ff :FuzzyFiles<CR>
nnoremap <silent> <leader>fi :FuzzyCommands<CR>
nnoremap <silent> <leader>fr :FuzzyGrep<CR>
nnoremap <silent> <leader>ft :FuzzyBuffers<CR>
nnoremap <silent> <leader>fh :FuzzyHighlights<CR>
```

## Options

```vim
" set to 0 to disable default keybindings
" default to 1
let g:enable_fuzzyy_keymaps = 0

" make FuzzyFiles respect .gitignore if set to 1
" only work when
" 1. inside a git repository and git is installed
" 2. or fd is installed
" default to 0
let g:files_respect_gitignore = 1

" change navigation keymaps
" the following is the default
let g:fuzzyy_keymaps = {
\     'menu_up': ["\<c-p>", "\<Up>"],
\     'menu_down': ["\<c-n>", "\<Down>"],
\     'menu_select': ["\<CR>"],
\     'preview_up': ["\<c-u>"],
\     'preview_down': ["\<c-d>"],
\     'exit': ["\<Esc>", "\<c-c>", "\<c-[>"],
\ }

" change highlight of the matched text when searching
" default to cursearch
let g:fuzzyy_menu_matched_hl = 'cursearch'

" whether show devicons when using FuzzyFiles or FuzzyBuffers
" requires vim-devicons
" default to 1 if vim-devicons is installed, 0 otherwise
let g:fuzzyy_devicons = 1

" enable dropdown theme
" default to 0"
let g:fuzzyy_dropdown = 1
```

## API

This plugin also exposes API to build your custom picker.
If you need examples please refer to /autoload/fuzzy/colors.vim, helps.vim etc.

vim9
```vim
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
#       - key_callbacks: dictonary<key, callback(funcref)>, when pressing key,
#           callback will be called
# return:
#   - a list [menu_wid, prompt_wid]
#   - if has preview = 1, then return [menu_wid, prompt_wid, preview_wid]
selector.Start(...)
```

vim8

```vim
import autoload 'utils/selector.vim'

s:selector.Start(...)
```

