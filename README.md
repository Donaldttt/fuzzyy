# Fuzzyy

A fuzzy finder for files, strings, help documents and many other things.

It utilizes Vim's native matchfuzzypos function and popup window feature.

Fuzzyy strives to provide an out-of-box experience by using pre-installed
programs to handle complex tasks.

## Screenshot

![screenshot](https://i.imgur.com/3gkz8Hp.png)

[](https://i.imgur.com/3gkz8Hp.png)

## Requirements

- Vim >= 9.0 (plugin is written in vim9scipt, Vim 9+ required, NeoVim not
  supported)

### Suggested dependencies

- [ripgrep](https://github.com/BurntSushi/ripgrep) - used for FuzzyGrep and
  FuzzyFiles if installed, faster than the defaults and respects gitignore
- [vim-devicons](https://github.com/ryanoasis/vim-devicons) - used to show
  [devicons](https://devicon.dev/) when listing files if installed

### Optional dependencies

- [ag](https://github.com/ggreer/the_silver_searcher) - used for FuzzyGrep if
  ripgrep not installed
- [fd](https://github.com/sharkdp/fd) - used for FuzzyFiles if ripgrep not
  installed
- [git](https://git-scm.com/) - used for FuzzyGrep and FuzzyFiles when inside git
  repo and no alternative dependency installed
- [ctags](https://ctags.io) - used to generate tags for FuzzyTags (Universal
  Ctags implementation is required)

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

| Command               | Description
| ---                   | ---
| FuzzyFiles            | search files in current working directory (CWD)
| FuzzyFilesRoot        | search files in the project/vcs root directory
| FuzzyGrep [str]       | search for string in CWD, use [str] if provided
| FuzzyGrepRoot [str]   | search for string in the project/vcs root directory
| FuzzyBuffers          | search opened buffers
| FuzzyMru              | search most recent used files
| FuzzyMruCwd           | search most recent used files in CWD
| FuzzyMruRoot          | search most recent used files in project/vcs root
| FuzzyInBuffer [str]   | search for string in buffer, use [str] if provided
| FuzzyHelp             | search subjects/tags in :help documents
| FuzzyCommands         | search commands
| FuzzyColors           | search installed color schemes
| FuzzyCmdHistory       | search command history
| FuzzyHighlights       | search highlight groups
| FuzzyTags             | search tags in tagfiles(), see `:h tags`
| FuzzyTagsRoot         | search tags in the project/vcs root directory
| FuzzyGitFiles         | search files in output from `git ls-files`
| FuzzyHelps            | deprecated alias for FuzzyHelp, will be removed
| FuzzyMRUFiles         | deprecated alias for FuzzyMru, will be removed

- For FuzzyGrep and FuzzyInBuffer, you can define a keymap like this to search
  the word under cursor.
  ```vim
  nnoremap <leader>fw :FuzzyGrep <C-R><C-W><CR>
  ```
- FuzzyGrep requires one of `rg`, `ag`, `grep` or `FINDSTR` commands. If neither
  `rg` or `ag` are installed it will also use `git-grep` when in a git repo.
- FuzzyFiles requires one of `rg`, `fd`, `find` or `powershell` commands. If
  neither `rg` or `fd` are installed it will also use `git-ls-files` when in a
  git repo.
- FuzzyTags requires `ctags` (Universal Ctags) to generate a tags file.

## Mappings

```vim
nnoremap <silent> <leader>fb :FuzzyBuffers<CR>
nnoremap <silent> <leader>fc :FuzzyCommands<CR>
nnoremap <silent> <leader>ff :FuzzyFiles<CR>
nnoremap <silent> <leader>fg :FuzzyGrep<CR>
nnoremap <silent> <leader>fh :FuzzyHelp<CR>
nnoremap <silent> <leader>fi :FuzzyInBuffer<CR>
nnoremap <silent> <leader>fm :FuzzyMru<CR>
nnoremap <silent> <leader>fr :FuzzyMruCwd<CR>
```

You can set `g:fuzzyy_enable_mappings = 0` to disable these default mappings.

Fuzzyy will not overwrite mappings from your vimrc when adding default mappings.

## Navigation

- \<CTRL-P> or \<Up> moves up by one line in the menu window
- \<CTRL-N> or \<Down> moves down by one line in the menu window
- \<CTRL-U> moves up by half a page in the preview window
- \<CTRL-D> moves down by half a page in the preview window
- \<CTRL-I> moves up by one line in the preview window
- \<CTRL-F> moves down by one line in the preview window
- \<CTRL-C> or \<ESC> exits Fuzzyy, closing all the windows

You can use `g:fuzzyy_keymaps` to change these defaults.

Navigation with the mouse is also supported. A single mouse click in the menu
window moves the cursor line, double click selects a line. The mouse wheel can
be used to scroll the preview window, but not the menu window.

**Command specific keymaps**

- FuzzyHighlights
  - \<CTRL-K> toggle white preview background color

- FuzzyMru
  - \<CTRL-K> toggle between all MRU files and CWD only

- FuzzyBuffers, FuzzyFiles, FuzzyGrep, FuzzyInBuffer, FuzzyMru, FuzzyTags
  - \<CTRL-S> open selected file in horizontal split
  - \<CTRL-V> open selected file in vertical split
  - \<CTRL-T> open selected file in new tab page

- FuzzyBuffers, FuzzyFiles, FuzzyGrep, FuzzyInBuffer, FuzzyMru
  - \<CTRL-Q> send results to quickfix list

Send results to quickfix list only includes results currently in the menu buffer,
which effectively limits the results to a few hundred at most (this is probably
what you want, sending thousands of results to the quickfix list is slow).

## Options

### g:fuzzyy_enable_mappings
Set to 0 to disable default mappings. Default to 1
```vim
let g:fuzzyy_enable_mappings = 1
```

### g:fuzzyy_devicons
Show devicons when listing files (e.g. FuzzyFiles, FuzzyBuffers). Requires
[vim-devicons](https://github.com/ryanoasis/vim-devicons). Default 1 (show
devicons if installed), set to 0 to always disable
```vim
let g:fuzzyy_devicons = 1
```

### g:fuzzyy_dropdown
Enable dropdown theme (prompt at top rather than bottom). Default 0
```vim
let g:fuzzyy_dropdown = 0
```

### g:fuzzyy_borderchars
Set the borderchars of popup windows. Must be a list of 8 characters.
```vim
let g:fuzzyy_borderchars = ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
```

### g:fuzzyy_reuse_windows
Fuzzyy avoids opening files in windows containing special buffers, like buffers
created by file explorer plugins or help and quickfix buffers. Use this to add
exceptions, the match is on either buftype or filetype. Default `['netrw']`
(Netrw is Vim's built-in file explorer plugin)
```vim
let g:fuzzyy_reuse_windows = ['netrw']
```
Example usage
```vim
let g:fuzzyy_reuse_windows = ['netrw', 'bufexplorer', 'mru', 'terminal']
```

### g:fuzzyy_respect_gitignore
Make FuzzyFiles & FuzzyGrep respect `.gitignore`. Default 1. Only work when
1. inside a git repository and git is installed
2. or either rg or fd is installed for FuzzyFiles
3. or either rg or ag is installed for FuzzyGrep
```vim
let g:fuzzyy_respect_gitignore = 1
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzyy_files_respect_gitignore` and `g:fuzzyy_grep_respect_gitignore`

### g:fuzzyy_include_hidden
Make FuzzyFiles & FuzzyGrep include hidden files. Default 1. Only applied when
1. rg, fd or PowerShell Get-ChildItem used with FuzzyFiles
2. rg or ag used with FuzzyGrep
```vim
let g:fuzzyy_include_hidden = 1
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzyy_files_include_hidden` and `g:fuzzyy_grep_include_hidden`

### g:fuzzyy_follow_symlinks
Make FuzzyFiles & FuzzyGrep follow symbolic links. Not applied when using
git-ls-files, git-grep or FINDSTR. Default 0
```vim
let g:fuzzyy_follow_symlinks = 0
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzyy_files_follow_symlinks` and `g:fuzzyy_grep_follow_symlinks`

### g:fuzzyy_root_patterns
Patterns to find a project root in supported commands, e.g. FuzzyFilesRoot.
These commands find a "root" directory to use as the working directory by
walking up the direcrory tree looking for any match of these glob patterns.
Default is intentionally conservative, using common VCS root markers only.
```vim
let g:fuzzyy_root_patterns = ['.git', '.hg', '.svn']
```
Example usage
```vim
let g:fuzzyy_root_patterns = ['.git', 'package.json', 'pyproject.toml']
```

### g:fuzzyy_exclude_file
Make FuzzyFiles, FuzzyGrep, and FuzzyMru always exclude files matching these
glob patterns. Applies whether `.gitignore` is respected or not. Default
`['*.swp', 'tags']`
```vim
let g:fuzzyy_exclude_file = ['*.swp', 'tags']
```
This option can also be set specifically for FuzzyFiles, FuzzyGrep, and FuzzyMru
using `g:fuzzyy_files_exclude_file` and `g:fuzzyy_grep_exclude_file` etc.

### g:fuzzyy_exclude_dir
Make FuzzyFiles, FuzzyGrep, and FuzzyMru always exclude these directories.
Applies whether `.gitignore` is respected or not. Default
`['.git', '.hg', '.svn']`
```vim
let g:fuzzyy_exclude_dir = ['.git', '.hg', '.svn']
```
This option can also be set specifically for FuzzyFiles, FuzzyGrep, and FuzzyMru
using `g:fuzzyy_files_exclude_dir` and `g:fuzzyy_grep_exclude_dir` etc.

### g:fuzzyy_ripgrep_options
Add custom ripgrep options for FuzzyFiles & FuzzyGrep. Appended to the generated
options. Default `[]`
```vim
let g:fuzzyy_ripgrep_options = []
```
Example usage
```vim
let g:fuzzyy_ripgrep_options = [
  \ "--no-config",
  \ "--max-filesize=1M",
  \ "--no-ignore-parent",
  \ "--ignore-file " . expand('~/.ignore')
  \ ]
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzyy_files_ripgrep_options` and `g:fuzzyy_grep_ripgrep_options`

### g:fuzzyy_devicons_color_table
Add custom mappings for colorizing devicon glyphs. A dictionary of filename
patterns and colors. Colors must be either color names in Vim's `v:colornames`
dict or hex colors in `#rrggbb` format. Default {}
```vim
let g:fuzzyy_devicons_color_table = {}
```
Example usage
```vim
let g:fuzzyy_devicons_color_table = { '*.vala': 'mediumpurple', '*.jl': '#9558B2' }
```

### g:fuzzyy_devicons_glyph_func
Specify a custom function for obtaining devicon glyphs from file names or paths.
By default Fuzzyy integrates with vim-devicons to obtain glyphs and measure byte
widths. You can use this option to obtain devicon glyphs from another nerdfont
compatible plugin, or your own custom function. Default ''
```vim
let g:fuzzyy_devicons_glyph_func = ''
```
Example usage
```vim
let g:fuzzyy_devicons_glyph_func = 'nerdfont#find'
```
The function should take a single string argument and return a single glyph.

### g:fuzzyy_devicons_color_func
Specify a custom function for colorizing devicon glyphs. By default Fuzzyy does
this with an internal function using a small set of common file name patterns
and colors, but you may want more extensive support for file name patterns not
recognised by Fuzzyy and to apply the same colors to Fuzzyy as other plugins.
Default ''
```vim
let g: fuzzyy_devicons_color_func = ''
```
Example usage
```vim
let g: fuzzyy_devicons_color_func = 'glyph_palette#apply'
```
The function should take no arguments and use matchadd() to add highlighting.

### g:fuzzyy_keymaps
Change navigation keymaps. The following are the defaults
```vim
let g:fuzzyy_keymaps = {
  \ 'menu_up': ["\<c-p>", "\<Up>"],
  \ 'menu_down': ["\<c-n>", "\<Down>"],
  \ 'menu_select': ["\<CR>"],
  \ 'preview_up': ["\<c-i>"],
  \ 'preview_down': ["\<c-f>"],
  \ 'preview_up_half_page': ["\<c-u>"],
  \ 'preview_down_half_page': ["\<c-d>"],
  \ 'cursor_begining': ["\<c-a>"],          " move cursor to the begining of the line in the prompt
  \ 'cursor_end': ["\<c-e>"],               " move cursor to the end of the line in the prompt
  \ 'backspace': ["\<bs>"],
  \ 'delete_all': ["\<c-k>"],               " delete whole line of the prompt
  \ 'delete_prefix': [],                    " delete to the start of the line
  \ 'exit': ["\<Esc>", "\<c-c>", "\<c-[>"], " exit fuzzyy
  \ }
```

### g:fuzzyy_buffers_exclude
FuzzyBuffers will exclude the buffers in this list. Buffers not included in
Vim's buffer list are excluded by default, so this is only necessary for buffers
included in Vim's buffer list, but you want hidden by FuzzyBuffers. Default `[]`
```vim
let g:fuzzyy_buffers_exclude = []
```

### g:fuzzyy_buffers_keymap
FuzzyBuffer keymap for commands specific to FuzzyBuffers. The following are the
defaults
```vim
let g:fuzzyy_buffers_keymap = {
  \ 'delete_buffer': "",
  \ 'close_buffer': "\<c-l>",
  \ }
```

### g:fuzzyy_window_layout
Window layout configuration. The general defaults for window layout options are:
```
'preview': 1,         " 1 means enable preview window, 0 means disable
'preview_ratio': 0.5, " 0.5 means preview window will take 50% of the layout
'width': 0.8,         " 0.8 means total width of the layout will take 80% of the screen
'height': 0.8,        " 0.8 means total height of the layout will take 80% of the screen
'xoffset': auto       " x offset of the windows, 0.1 means 10% from left of the screen
'yoffset': auto       " x offset of the windows, 0.1 means 10% from top of the screen
```
This configuration is also customised per selector, with the following defaults:
```vim
\ {
\   'files': {},
\   'grep': {},
\   'buffers': {},
\   'mru': {},
\   'tags': {},
\   'highlights': {},
\   'cmdhistory': {
\     'width': 0.6,
\   },
\   'colors': {
\     'width': 0.25,
\     'xoffset': 0.7,
\   },
\     'commands': {
\     'width': 0.4,
\   },
\   help: {
\     preview_ratio': 0.6
\   },
\   'inbuffer': {},
\ }
```

Values set in `g:fuzzyy_window_layout` are merged with the defaults above.
For example, you can disable preview window for FuzzyFiles and friends with:
```vim
let g:fuzzyy_window_layout = { 'files': { 'preview': 0 } }
```
or you change the width of the preview window for FuzzyColors with:
```vim
let g:fuzzyy_window_layout = { 'colors': { 'width': 0.4 } }
```
preview is ignored by commands that do not support it, e.g. FuzzyCmdHistory\
x and y offsets are by default calculated to center the windows on the screen\
width, height, and x and y offsets > 0 and < 1 are resolved as percentages\
width, height, and x and y offsets >= 1 are fixed numbers of lines and cols\
invalid values for preview_ratio, width, height, and x and y offsets are ignored

### g:fuzzyy_async_step
Fuzzyy mimics async processing to fuzzy match in batches, which avoids problems
running Vim's built in fuzzy matching on massive lists at once. The size of
these batches is the async step value, which defaults to 10,000. This default
should work well for most developer workstations, but you might want to reduce
if you notice a lack of responsiveness on low spec machines
```vim
let g:fuzzyy_async_step = 10000
```

## Syntax highlighting

It is also possible to modify the colors used for highlighting. The defaults are
shown below, you can change them in your vimrc. See :help :highlight if you are
unfamiliar with Vim highlighting

```vim
highlight default link fuzzyyCursor Search
highlight default link fuzzyyNormal Normal
highlight default link fuzzyyBorder Normal
highlight default link fuzzyyMatching Special
highlight default link fuzzyyPreviewMatch CurSearch
```
