if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script noclear

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

# Deprecated options
if exists('g:enable_fuzzyy_keymaps')
    echo 'fuzzyy: g:enable_fuzzyy_keymaps is deprecated, use g:fuzzyy_enable_mappings'
    g:fuzzyy_enable_mappings = g:enable_fuzzyy_keymaps
endif

g:fuzzyy_enable_mappings = exists('g:fuzzyy_enable_mappings') ? g:fuzzyy_enable_mappings : 1
g:fuzzyy_respect_gitignore = exists('g:fuzzyy_respect_gitignore') ? g:fuzzyy_respect_gitignore : 1
g:fuzzyy_follow_symlinks = exists('g:fuzzyy_follow_symlinks') ? g:fuzzyy_follow_symlinks : 0
g:fuzzyy_include_hidden = exists('g:fuzzyy_include_hidden') ? g:fuzzyy_include_hidden : 1
g:fuzzyy_exclude_file = exists('g:fuzzyy_exclude_file')
    && type(g:fuzzyy_exclude_file) == v:t_list ? g:fuzzyy_exclude_file : ['*.swp', 'tags']
g:fuzzyy_exclude_dir = exists('g:fuzzyy_exclude_dir')
    && type(g:fuzzyy_exclude_dir) == v:t_list ? g:fuzzyy_exclude_dir : ['.git', '.hg', '.svn']
g:fuzzyy_ripgrep_options = exists('g:fuzzyy_ripgrep_options')
    && type(g:fuzzyy_ripgrep_options) == v:t_list ? g:fuzzyy_ripgrep_options : []

# window layout
# you can override it by setting g:fuzzyy_window_layout
# e.g. let g:fuzzyy_window_layout = { 'files': { 'preview': 0 } }
# default value:
var windows = {
    files: {
        preview: 1,         # 1 means enable preview window, 0 means disable
        preview_ratio: 0.5, # 0.5 means preview window will take 50% of the layout
        width: 0.8,         # 0.8 means total width of the layout will take 80% of the screen
        height: 0.8,        # 0.8 means total height of the layout will take 80% of the screen
    },
    grep: {
        preview: 1,
    },
    buffers: {
        preview: 1,
    },
    mru: {
        preview: 1,
    },
    highlights: {
        preview: 1,
        preview_ratio: 0.7,
    },
    cmdhistory: {
        width: 0.6,
    },
    colors: {
        width: 0.25,
        xoffset: 0.7,
    },
    commands: {
        width: 0.4,
    },
    help: {
        preview: 1,
        preview_ratio: 0.6, # reasonable default for a laptop to avoid wrapping
    },
    inbuffer: {
        width: 0.7,
    },
}

if exists('g:fuzzyy_window_layout') && type(g:fuzzyy_window_layout) == v:t_dict
    for [key, value] in items(windows)
        if has_key(g:fuzzyy_window_layout, key)
            windows[key] = extend(value, g:fuzzyy_window_layout[key])
        endif
    endfor
endif

highlight default link fuzzyyCursor Search
highlight default link fuzzyyNormal Normal
highlight default link fuzzyyBorder Normal
highlight default link fuzzyyMatching Special
highlight default link fuzzyyPreviewMatch CurSearch

import autoload '../autoload/fuzzy/commands.vim'
import autoload '../autoload/fuzzy/grep.vim'
import autoload '../autoload/fuzzy/files.vim'
import autoload '../autoload/fuzzy/help.vim'
import autoload '../autoload/fuzzy/colors.vim'
import autoload '../autoload/fuzzy/inbuffer.vim'
import autoload '../autoload/fuzzy/buffers.vim'
import autoload '../autoload/fuzzy/highlights.vim'
import autoload '../autoload/fuzzy/cmdhistory.vim'
import autoload '../autoload/fuzzy/mru.vim'

command! -nargs=? FuzzyGrep grep.Start(windows.grep, <f-args>)
command! -nargs=0 FuzzyFiles files.Start(windows.files)
command! -nargs=0 FuzzyHelp help.Start(windows.help)
command! -nargs=0 FuzzyColors colors.Start(windows.colors)
command! -nargs=? FuzzyInBuffer inbuffer.Start(windows.inbuffer, <f-args>)
command! -nargs=0 FuzzyCommands commands.Start(windows.commands)
command! -nargs=0 FuzzyBuffers buffers.Start(windows.buffers)
command! -nargs=0 FuzzyHighlights highlights.Start(windows.highlights)
command! -nargs=0 FuzzyGitFiles files.Start(windows.files, 'git ls-files')
command! -nargs=0 FuzzyCmdHistory cmdhistory.Start(windows.cmdhistory)
command! -nargs=0 FuzzyMru mru.Start(windows.mru)
command! -nargs=0 FuzzyMruCwd mru.Start(windows.mru, getcwd())

if g:fuzzyy_enable_mappings
    nnoremap <silent> <leader>fb :FuzzyBuffers<CR>
    nnoremap <silent> <leader>fc :FuzzyCommands<CR>
    nnoremap <silent> <leader>ff :FuzzyFiles<CR>
    nnoremap <silent> <leader>fg :FuzzyGrep<CR>
    nnoremap <silent> <leader>fh :FuzzyHelp<CR>
    nnoremap <silent> <leader>fm :FuzzyMru<CR>
endif
