j# Fuzzyy

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
| FuzzyGrep \<args> | grep string in project. if argument is given, it will search the \<args> | \<leader>fr    |
| FuzzyFiles      | search files in project        | \<leader>ff    |
| FuzzyHelps      | search :help documents         | \<leader>fd    |
| FuzzyColors     | search installed colorscheme   | \<leader>fc    |
| FuzzyInBuffer  \<args> | search lines in current buffer. if argument is given, it will search the \<args> | \<leader>fb    |
| FuzzyCommands   | search commands                | \<leader>fi    |
| FuzzyBuffers    | search opened buffers          | \<leader>ft    |
| FuzzyHighlights | search highlights              | \<leader>fh    |
| FuzzyMRUFiles | search the most recent used files. set g:enable_fuzzyy_MRU_files = 1 to enable this command(not enable by default)    | \<leader>fm    |
| FuzzyGitFiles |  like FuzzyFiles but only shows file in git project  | None    |

- For FuzzyGrep and FuzzyInBuffer, you can define a keymap like this to search the
word under cursor.
    ```vim
        nnoremap <Space>f :FuzzyGrep <C-R><C-W><CR>
    ```
- FuzzyGrep requires any of grep, ag or rg command.

- FuzzyFiles uses find command in unix (if not found it will use vim's glob function,
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
" default to 0
let g:fuzzyy_dropdown = 1

" enable FuzzyMRUFiles command
" default to 0
let g:enable_fuzzyy_MRU_files = 1

```

## Credit

The code in autoload/utils/mru.vim is modified from [yegappan/mru](https://github.com/yegappan/mru).
