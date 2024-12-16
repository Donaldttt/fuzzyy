# Fuzzyy

A fuzzy picker for files, strings, help documents and many other things.

It utilizes Vim's native matchfuzzypos function and popup window feature.

Fuzzyy strives to provide an out-of-box experience by using pre-installed
programs to handle complex tasks.

## Screenshots

![screenshot](https://github.com/Donaldttt/resources/blob/main/fuzzyy/demo.png)

[gif](https://github.com/Donaldttt/resources/blob/main/fuzzyy/demo.gif)

## Requirements

- Vim >= 9.0 (there is an old vim8 branch, which works but is no longer maintained)

## Suggested dependencies
- [ripgrep](https://github.com/BurntSushi/ripgrep) (used for FuzzyGrep and
  FuzzyFiles if installed, faster than the defaults and respects gitignore)
- [vim-devicons](https://github.com/ryanoasis/vim-devicons) (used to show
  [devicons](https://devicon.dev/) when listing files if installed)

## Optional dependencies
- [ag](https://github.com/ggreer/the_silver_searcher) (used for FuzzyGrep if
  ripgrep not installed)
- [fd](https://github.com/sharkdp/fd) (used for FuzzyFiles if ripgrep not installed)
- [git](https://git-scm.com/) (used for FuzzyGrep and FuzzyFiles when inside git
  repo and no alternative dependency installed)

## Install

Any plugin manager will work, or you can use Vim's built-in package support:

For vim-plug
```vim
Plug 'Donaldttt/fuzzyy'
```

As Vim package
```
git clone https://github.com/Donaldttt/fuzzyy ~/.vim/pack/Donaldttt/start/fuzzyy
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
- FuzzyGrep requires any of `rg`, `ag`, `grep` or `FINDSTR` command.

- FuzzyFiles uses `find` command on UNIX or PowerShell's `Get-ChildItem` on Windows.
  If `rg` of `fd` are installed they will be used instead, with `rg` preferred.

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

you can set `g:fuzzyy_enable_mappings = 0` to disable default mappings

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
let g:fuzzyy_enable_mappings = 0

" Show devicons when using FuzzyFiles or FuzzyBuffers
" Requires vim-devicons
" Default to 1 if vim-devicons is installed, 0 otherwise
let g:fuzzyy_devicons = 1

" Enable dropdown theme (prompt at top rather than bottom)
" Default to 0
let g:fuzzyy_dropdown = 0

" DEPRECATED: mru is always enabled
" now this option has no effect
let g:enable_fuzzyy_MRU_files = 1

" Make FuzzyFiles respect .gitignore if possible
" only work when
" 1. inside a git repository and git is installed
" 2. or either rg or fd is installed
" Default to 1
let g:fuzzyy_files_respect_gitignore = 1

" Make FuzzyGrep respect .gitignore if possible
" only work when
" 1. inside a git repository and git is installed
" 2. or either rg or ag is installed
" Default to 1
let g:fuzzyy_grep_respect_gitignore = 1

" Make FuzzyFiles always include hidden files
" Only applied with rg, fd and PowerShell Get-ChildItem
" Default to 1
let g:fuzzyy_files_include_hidden = 1

" Make FuzzyGrep always include hidden files
" Only applied with rg and ag
" Default to 1
let g:fuzzyy_grep_include_hidden = 1

" Make FuzzyFiles follow symbolic links
" Not applied when using git-ls-files
" Default to 0
let g:fuzzyy_files_follow_symlinks = 0

" Make FuzzyGrep follow symbolic links
" Not applied when using git-grep or FINDSTR
" Default to 0
let g:fuzzyy_grep_follow_symlinks = 0

" FuzzyFiles will always exclude the files/directory in these two lists
" The following is the default
let g:fuzzyy_files_exclude_file = ['*.swp', 'tags']
let g:fuzzyy_files_exclude_dir = ['.git', '.hg', '.svn']

" FuzzyGrep will always exclude the files/directory in these two lists
" These are different to the FuzzyyFiles lists, with the same defaults
" The following is the default
let g:fuzzyy_grep_exclude_file = ['*.swp', 'tags']
let g:fuzzyy_grep_exclude_dir = ['.git', '.hg', '.svn']

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
\     'backspace': ["\<bs>"],
\     'delete_all': ["\<c-k>"],               " delete whole line of the prompt
\     'delete_prefix': [],                    " delete to the start of the line
\     'exit': ["\<Esc>", "\<c-c>", "\<c-[>"], " exit fuzzyy
\ }

" FuzzyMRUFiles default shows MRU files that are in the current project
" default to 0
let g:fuzzyy_mru_project_only = 0

" FuzzyBuffers will exclude the buffers in this list. Buffers not included in
" Vim's buffer list are excluded by default, so this is only necessary for
" buffers included in Vim's buffer list, but you want hidden by FuzzyBuffers
" default to []
let g:fuzzyy_buffers_exclude = []

" FuzzyBuffer keymap for commands speicific to FuzzyBuffers
" default to is the following
let g:fuzzyy_buffers_keymap = {
\    'delete_buffer': "",
\    'close_buffer': "\<c-l>",
\ }

" window layout configuraton
" you can override it by setting g:fuzzyy_window_layout
" e.g. You can disable preview window for FuzzyFiles command by doing this:
" let g:fuzzyy_window_layout = { 'FuzzyFiles': { 'preview': 0 } }
" default value:
let g:fuzzyy_window_layout = {
\    'FuzzyFiles': {
\        'preview': 1,         " 1 means enable preview window, 0 means disable
\        'preview_ratio': 0.5, " 0.5 means preview window will take 50% of the layout
\        'width': 0.8,         " 0.8 means total width of the layout will take 80% of the screen
\    },
\    'FuzzyGrep': {
\        'preview': 1,
\        'preview_ratio': 0.5,
\        'width': 0.8,
\    },
\    'FuzzyBuffers': {
\        'preview': 1,
\        'preview_ratio': 0.5,
\        'width': 0.8,
\    },
\    'FuzzyMRUFiles': {
\        'preview': 1,
\        'preview_ratio': 0.5,
\        'width': 0.8,
\    },
\    'FuzzyHighlights': {
\        'preview': 1,
\        'preview_ratio': 0.7,
\        'width': 0.8,
\    },
\ }

" It is also possible to modify the colors used for highlighting
" The defaults are shown below, you can change them in your vimrc
" See :help :highlight if you are unfamiliar with Vim highlighting
highlight default link fuzzyyCursor Search
highlight default link fuzzyyNormal Normal
highlight default link fuzzyyBorder Normal
highlight default link fuzzyyMatching Special
highlight default link fuzzyyPreviewMatch CurSearch
```
