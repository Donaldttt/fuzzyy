if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script noclear

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

var warnings = []
if &encoding != 'utf-8'
    warnings += ['fuzzyy: Vim encoding is ' .. &encoding .. ', utf-8 is required for popup borders etc.']
endif

# Options
g:fuzzyy_enable_mappings = exists('g:fuzzyy_enable_mappings') ? g:fuzzyy_enable_mappings : 1
g:fuzzyy_respect_gitignore = exists('g:fuzzyy_respect_gitignore') ? g:fuzzyy_respect_gitignore : 1
g:fuzzyy_respect_wildignore = exists('g:fuzzyy_respect_wildignore') ? g:fuzzyy_respect_wildignore : 0
g:fuzzyy_follow_symlinks = exists('g:fuzzyy_follow_symlinks') ? g:fuzzyy_follow_symlinks : 0
g:fuzzyy_include_hidden = exists('g:fuzzyy_include_hidden') ? g:fuzzyy_include_hidden : 1
g:fuzzyy_exclude_file = exists('g:fuzzyy_exclude_file')
    && type(g:fuzzyy_exclude_file) == v:t_list ? g:fuzzyy_exclude_file : ['*.swp', 'tags']
g:fuzzyy_exclude_dir = exists('g:fuzzyy_exclude_dir')
    && type(g:fuzzyy_exclude_dir) == v:t_list ? g:fuzzyy_exclude_dir : ['.git', '.hg', '.svn']
g:fuzzyy_ripgrep_options = exists('g:fuzzyy_ripgrep_options')
    && type(g:fuzzyy_ripgrep_options) == v:t_list ? g:fuzzyy_ripgrep_options : []

if g:fuzzyy_respect_wildignore
    extend(g:fuzzyy_exclude_file, split(&wildignore, ','))
endif

# window layout customization for particular selectors
# you can override it by setting g:fuzzyy_window_layout
# e.g. let g:fuzzyy_window_layout = { 'files': { 'preview': 0 } }
var windows: dict<any> = {
    files: {
        prompt_title: 'Find Files'
    },
    grep: {
        prompt_title: 'Live Grep'
    },
    buffers: {
        prompt_title: 'Buffers'
    },
    mru: {
        prompt_title: 'Recent Files'
    },
    tags: {
        prompt_title: 'Tags'
    },
    highlights: {
        prompt_title: 'Highlight Groups',
        preview_ratio: 0.7,
    },
    cmdhistory: {
        prompt_title: 'Command History',
        width: 0.6,
    },
    colors: {
        prompt_title: 'Color Schemes',
        width: 0.25,
        xoffset: 0.6,
    },
    commands: {
        prompt_title: 'Commands',
        width: 0.4,
    },
    help: {
        prompt_title: 'Help',
        preview_ratio: 0.6,
    },
    inbuffer: {
        prompt_title: 'Lines in Buffer',
    },
}
if exists('g:fuzzyy_window_layout') && type(g:fuzzyy_window_layout) == v:t_dict
    for [key, value] in items(windows)
        if has_key(g:fuzzyy_window_layout, key)
            windows[key] = extend(value, g:fuzzyy_window_layout[key])
        endif
    endfor
endif

highlight default link fuzzyyCursor Cursor
highlight default link fuzzyyNormal Normal
highlight default link fuzzyyBorder Normal
highlight default link fuzzyyCounter NonText
highlight default link fuzzyyMatching Special
highlight default link fuzzyyPreviewMatch CurSearch

import autoload '../autoload/fuzzyy/utils/launcher.vim'
import autoload '../autoload/fuzzyy/utils/helpers.vim'

command! -nargs=? FuzzyGrep launcher.Start('grep', extendnew(windows.grep, { search: <q-args> }))
command! -nargs=? FuzzyGrepRoot launcher.Start('grep', extendnew(windows.grep, { cwd: helpers.GetRootDir(), 'search': <q-args> }))
command! -nargs=0 FuzzyFiles launcher.Start('files', windows.files)
command! -nargs=? FuzzyFilesRoot launcher.Start('files', extendnew(windows.files, { cwd: helpers.GetRootDir() }))
command! -nargs=0 FuzzyHelp launcher.Start('help', windows.help)
command! -nargs=0 FuzzyColors launcher.Start('colors', windows.colors)
command! -nargs=? FuzzyInBuffer launcher.Start('inbuffer', extendnew(windows.inbuffer, { search: <q-args> }))
command! -nargs=0 FuzzyCommands launcher.Start('commands', windows.commands)
command! -nargs=0 FuzzyBuffers launcher.Start('buffers', windows.buffers)
command! -nargs=0 FuzzyHighlights launcher.Start('highlights', windows.highlights)
command! -nargs=0 FuzzyGitFiles launcher.Start('files', extendnew(windows.files, { command: 'git ls-files' }))
command! -nargs=0 FuzzyCmdHistory launcher.Start('cmdhistory', windows.cmdhistory)
command! -nargs=0 FuzzyMru launcher.Start('mru', windows.mru)
command! -nargs=0 FuzzyMruCwd launcher.Start('mru', extendnew(windows.mru, { cwd: getcwd() }))
command! -nargs=0 FuzzyMruRoot launcher.Start('mru', extendnew(windows.mru, { cwd: helpers.GetRootDir() }))
command! -nargs=0 FuzzyTags launcher.Start('tags', windows.tags)
command! -nargs=0 FuzzyTagsRoot launcher.Start('tags', extendnew(windows.tags, { cwd: helpers.GetRootDir() }))
command! -nargs=0 FuzzyPrevious launcher.Resume()

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
        '<leader>fp': ':FuzzyPrevious<CR>',
        '<leader>fr': ':FuzzyMruCwd<CR>'
    }
    for [lhs, rhs] in items(mappings)
        if empty(maparg(lhs, 'n'))
            exe 'nnoremap <silent> ' .. lhs .. ' ' .. rhs
        endif
    endfor
endif

# Load compatibility hacks on VimEnter, after other plugins are loaded
augroup fuzzyyCompat
  au!
  autocmd VimEnter * runtime! compat/fuzzyy.vim
augroup END
