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
if &encoding != 'utf-8'
    warnings += ['fuzzyy: Vim encoding is ' .. &encoding .. ', utf-8 is required for popup borders etc.']
endif
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

# window layout customization for particular selectors
# you can override it by setting g:fuzzyy_window_layout
# e.g. let g:fuzzyy_window_layout = { 'files': { 'preview': 0 } }
var windows: dict<any> = {
    files: {},
    grep: {},
    buffers: {},
    mru: {},
    tags: {},
    highlights: {
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
        preview_ratio: 0.6,
    },
    inbuffer: {},
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
import autoload '../autoload/fuzzyy/tags.vim'
import autoload '../autoload/fuzzyy/utils/selector.vim'

command! -nargs=? FuzzyGrep grep.Start(extendnew(windows.grep, { search: <q-args> }))
command! -nargs=? FuzzyGrepRoot grep.Start(extendnew(windows.grep, { cwd: selector.GetRootDir(), 'search': <q-args> }))
command! -nargs=0 FuzzyFiles files.Start(windows.files)
command! -nargs=? FuzzyFilesRoot files.Start(extendnew(windows.files, { cwd: selector.GetRootDir() }))
command! -nargs=0 FuzzyHelp help.Start(windows.help)
command! -nargs=0 FuzzyColors colors.Start(windows.colors)
command! -nargs=? FuzzyInBuffer inbuffer.Start(extendnew(windows.inbuffer, { search: <q-args> }))
command! -nargs=0 FuzzyCommands commands.Start(windows.commands)
command! -nargs=0 FuzzyBuffers buffers.Start(windows.buffers)
command! -nargs=0 FuzzyHighlights highlights.Start(windows.highlights)
command! -nargs=0 FuzzyGitFiles files.Start(extendnew(windows.files, { command: 'git ls-files' }))
command! -nargs=0 FuzzyCmdHistory cmdhistory.Start(windows.cmdhistory)
command! -nargs=0 FuzzyMru mru.Start(windows.mru)
command! -nargs=0 FuzzyMruCwd mru.Start(extendnew(windows.mru, { cwd: getcwd() }))
command! -nargs=0 FuzzyMruRoot mru.Start(extendnew(windows.mru, { cwd: selector.GetRootDir() }))
command! -nargs=0 FuzzyTags tags.Start(windows.tags)
command! -nargs=0 FuzzyTagsRoot tags.Start(extendnew(windows.tags, { cwd: selector.GetRootDir() }))

# Deprecated/renamed commands
def Warn(msg: string)
    if has('patch-9.0.0321')
        echow msg
    else
        timer_start(100, (_) => {
            echohl WarningMsg | echo msg | echohl None
        }, { repeat: 0 })
    endif
enddef
command! -nargs=0 FuzzyHelps Warn('fuzzyy: FuzzyHelps command is deprecated, use FuzzyHelp instead') | FuzzyHelp
command! -nargs=0 FuzzyMRUFiles Warn('fuzzyy: FuzzyMRUFiles command is deprecated, use FuzzyMru instead') | FuzzyMru

# Hack to only show a single line warning when startng the selector
# Avoids showing warnings on Vim startup and does not break selector
if len(warnings) > 0
    g:__fuzzyy_warnings_found = 1
    command! -nargs=0 FuzzyShowWarnings for warning in warnings | echo warning | endfor
endif

if g:fuzzyy_enable_mappings
    var mappings = {
        '<leader>fb': ':FuzzyBuffers<CR>',
        '<leader>fc': ':FuzzyCommands<CR>',
        '<leader>ff': ':FuzzyFiles<CR>',
        '<leader>fg': ':FuzzyGrep<CR>',
        '<leader>fh': ':FuzzyHelp<CR>',
        '<leader>fi': ':FuzzyInBuffer<CR>',
        '<leader>fm': ':FuzzyMru<CR>',
        '<leader>fr': ':FuzzyMruCwd<CR>'
    }
    for [lhs, rhs] in items(mappings)
        if empty(maparg(lhs, 'n'))
            exe 'nnoremap <silent> ' .. lhs .. ' ' .. rhs
        endif
    endfor
endif
