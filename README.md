# Fuzzyy

A fuzzy picker for files, strings, help documents and many other things.

It ultilizes vim's native matchfuzzypos function and popup window feature.

## Screenshots

![screenshot](https://github.com/Donaldttt/resources/blob/main/fuzzyy/demo.png)

[gif](https://github.com/Donaldttt/resources/blob/main/fuzzyy/demo.gif)

## Requirements

- vim > 9.0
    - The maintained version is written in vim9, but it also has a vim8 branch for older vim.
- any of grep, ag or rg for FuzzyGrep command
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
| FuzzyCmdHistory |  search command history  | None    |
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
- Patterns defined in `wildignore` option are excluded from the search.

## Navigation

Arrow keys or `ctrl + p`/ `ctrl + n` moves up/down the menu

`ctrl + u`/`ctrl + d` moves up/down the buffer by half page in preview window

`ctrl + i`/`ctrl + f` moves up/down the buffer by one line in preview window

you can set `g:fuzzyy_keymaps` to change these defaults.

### Command Specific keymaps
- FuzzyHighlights
    - `ctrl + k` toggle white preview background color
    - `Enter` will copy selected highlight

- FuzzyMRUFiles
    - `ctrl + k` toggle global or project MRU files

- FuzzyBuffers, FuzzyMRUFiles, FuzzyFiles, FuzzyGitFiles
    - `ctrl + s` open selected file in horizontal spliting
    - `ctrl + v` open selected file in vertical spliting
    - `ctrl + t` open selected file in new tab page

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
nnoremap <silent> <leader>fm :FuzzyMRUFiles<CR>
```

## Options

```vim
" Set to 0 to disable default keybindings
" Default to 1
let g:enable_fuzzyy_keymaps = 0

" Make FuzzyFiles respect .gitignore if set to 1
" only work when
" 1. inside a git repository and git is installed
" 2. or fd is installed
" Default to 0
let g:files_respect_gitignore = 1

" FuzzyFiles will exclude the files/directory in these two lists
" only work when g:files_respect_gitignore = 0
" The following is the default
let g:fuzzyy_files_ignore_file = ['*.beam', '*.so', '*.exe', '*.dll', '*.dump',
    '*.core', '*.swn', '*.swp']
var g:fuzzyy_files_ignore_dir = ['.git', '.hg', '.svn', '.rebar', '.eunit']

" Change navigation keymaps
" The following is the default
let g:fuzzyy_keymaps = {
\     'menu_up': ["\<c-p>", "\<Up>"],
\     'menu_down': ["\<c-n>", "\<Down>"],
\     'menu_select': ["\<CR>"],
\     'preview_up': ["\<c-i>"],
\     'preview_down': ["\<c-f>"],
\     'preview_up_half_page': ["\<c-u>"],
\     'preview_down_half_page': ["\<c-d>"],
\     'cursor_begining': ["\<c-a>"],          " move cursor to the begining of the line in the prompt
\     'cursor_end': ["\<c-e>"],               " move cursor to the end of the line in the prompt
\     'delete_all': ["\<c-k>"],               " delete whole line of the prompt
\.    'delete_prefix': [],                    " delete to the start of the line
\     'exit': ["\<Esc>", "\<c-c>", "\<c-[>"], " exit fuzzyy
\ }

" Change highlight of the matched text when searching
" Default to cursearch
let g:fuzzyy_menu_matched_hl = 'cursearch'

" Whether show devicons when using FuzzyFiles or FuzzyBuffers
" Requires vim-devicons
" Default to 1 if vim-devicons is installed, 0 otherwise
let g:fuzzyy_devicons = 1

" Whether enable dropdown theme
" Default to 0
let g:fuzzyy_dropdown = 0

" DEPRECATED: mru is always enabled
" now this option has no effect
let g:enable_fuzzyy_MRU_files = 1

" FuzzyMRUFiles default shows MRU files that are in the current project
" default to 0
let g:fuzzyy_mru_project_only = 0

" FuzzyBuffers will exclude the buffers in this list
" default to ['__vista__']
let g:fuzzyy_buffers_exclude = ['__vista__']

" window layout configuraton
" you can override it by setting g:fuzzyy_window_layout
" e.g. You can disable preview window for FuzzyFiles command by doing this:
" let g:fuzzyy_window_layout = { 'FuzzyFiles': { 'preview': 0 } }
" default value:
{
    'FuzzyFiles': {
        'preview': 1,         " 1 means enable preview window, 0 means disable
        'preview_ratio': 0.5, " 0.5 means preview window will take 50% of the layout
        'width': 0.8,         " 0.8 means total width of the layout will take 80% of the screen
    },
    'FuzzyGrep': {
        'preview': 1,
        'preview_ratio': 0.5,
        'width': 0.8,
    },
    'FuzzyBuffers': {
        'preview': 1,
        'preview_ratio': 0.5,
        'width': 0.8,
    },
    'FuzzyMRUFiles': {
        'preview': 1,
        'preview_ratio': 0.5,
        'width': 0.8,
    },
    'FuzzyHighlights': {
        'preview': 1,
        'preview_ratio': 0.7,
        'width': 0.8,
    },
}
```
