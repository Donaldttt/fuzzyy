if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script noclear

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

# Deprecated or removed options
var warnings = []
if exists('g:enable_fuzzyy_keymaps')
    warnings += ['fuzzyy: g:enable_fuzzyy_keymaps is deprecated, use g:fuzzyy_enable_mappings instead']
    g:fuzzyy_enable_mappings = g:enable_fuzzyy_keymaps
endif
if exists('g:fuzzyy_menu_matched_hl')
    warnings += ['fuzzyy: g:fuzzyy_menu_matched_hl is deprecated, use fuzzyyMatching highlight group instead']
    execute 'highlight default link fuzzyyMatching ' .. g:fuzzyy_menu_matched_hl
endif
if exists('g:files_only_git_files')
    warnings += ['fuzzyy: g:files_only_git_files is no longer supported, use :FuzzyGitFiles command instead']
endif
if exists('g:files_respect_gitignore')
    warnings += ['fuzzyy: g:files_respect_gitignore is deprecated, gitignore is now respected by default']
    g:fuzzyy_files_respect_gitignore = g:files_respect_gitignore
endif
if exists('g:fuzzyy_files_ignore_file')
    warnings += ['fuzzyy: g:fuzzyy_files_ignore_file is deprecated, use g:fuzzyy_files_exclude_file instead']
    g:fuzzyy_files_exclude_file = g:fuzzyy_files_ignore_file
endif
if exists('g:fuzzyy_files_ignore_dir')
    warnings += ['fuzzyy: g:fuzzyy_files_ignore_dir is deprecated, use g:fuzzyy_files_exclude_dir instead']
    g:fuzzyy_files_exclude_dir = g:fuzzyy_files_ignore_dir
endif
if exists('g:fuzzyy_mru_project_only')
    warnings += ['fuzzyy: g:fuzzyy_mru_project_only is no longer supported, use :FuzzyMruCwd command instead']
endif

# Options
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

import autoload '../autoload/fuzzyy/commands.vim'
import autoload '../autoload/fuzzyy/grep.vim'
import autoload '../autoload/fuzzyy/files.vim'
import autoload '../autoload/fuzzyy/help.vim'
import autoload '../autoload/fuzzyy/colors.vim'
import autoload '../autoload/fuzzyy/inbuffer.vim'
import autoload '../autoload/fuzzyy/buffers.vim'
import autoload '../autoload/fuzzyy/highlights.vim'
import autoload '../autoload/fuzzyy/cmdhistory.vim'
import autoload '../autoload/fuzzyy/mru.vim'

command! -nargs=? FuzzyGrep grep.Start(extend(windows.grep, { 'search': <q-args> }))
command! -nargs=0 FuzzyFiles files.Start(windows.files)
command! -nargs=0 FuzzyHelp help.Start(windows.help)
command! -nargs=0 FuzzyColors colors.Start(windows.colors)
command! -nargs=? FuzzyInBuffer inbuffer.Start(extend(windows.inbuffer, { 'search': <q-args> }))
command! -nargs=0 FuzzyCommands commands.Start(windows.commands)
command! -nargs=0 FuzzyBuffers buffers.Start(windows.buffers)
command! -nargs=0 FuzzyHighlights highlights.Start(windows.highlights)
command! -nargs=0 FuzzyGitFiles files.Start(extend(windows.files, { 'command': 'git ls-files' }))
command! -nargs=0 FuzzyCmdHistory cmdhistory.Start(windows.cmdhistory)
command! -nargs=0 FuzzyMru mru.Start(windows.mru)
command! -nargs=0 FuzzyMruCwd mru.Start(extend(windows.mru, { 'cwd': getcwd() }))

# Deprecated/renamed commands
command! -nargs=0 FuzzyHelps echo 'fuzzyy: FuzzyHelps command is deprecated, use FuzzyHelp instead' | FuzzyHelp
command! -nargs=0 FuzzyMRUFiles echo 'fuzzyy: FuzzyMRUFiles command is deprecated, use FuzzyMru instead' | FuzzyMru

# Hack to only show a single line warning when startng the selector
# Avoids showing warnings on Vim startup and does not break selector
if len(warnings) > 0
    g:__fuzzyy_warnings_found = 1
    command! -nargs=0 FuzzyShowWarnings for warning in warnings | echo warning | endfor
endif

if g:fuzzyy_enable_mappings
    nnoremap <silent> <leader>fb :FuzzyBuffers<CR>
    nnoremap <silent> <leader>fc :FuzzyCommands<CR>
    nnoremap <silent> <leader>ff :FuzzyFiles<CR>
    nnoremap <silent> <leader>fg :FuzzyGrep<CR>
    nnoremap <silent> <leader>fh :FuzzyHelp<CR>
    nnoremap <silent> <leader>fm :FuzzyMru<CR>
endif
