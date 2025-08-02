if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script noclear

if exists("g:loaded_fuzzbox")
  finish
endif
g:loaded_fuzzbox = 1

# Deprecated or removed options
var warnings = []
if &encoding != 'utf-8'
    warnings += ['fuzzbox: Vim encoding is ' .. &encoding .. ', utf-8 is required for popup borders etc.']
endif
if exists('g:enable_fuzzbox_keymaps')
    warnings += ['fuzzbox: g:enable_fuzzbox_keymaps is deprecated, use g:fuzzbox_enable_mappings instead']
    g:fuzzbox_enable_mappings = g:enable_fuzzbox_keymaps
endif
if exists('g:fuzzbox_menu_matched_hl')
    warnings += ['fuzzbox: g:fuzzbox_menu_matched_hl is deprecated, use fuzzboxMatching highlight group instead']
    execute 'highlight default link fuzzboxMatching ' .. g:fuzzbox_menu_matched_hl
endif
if exists('g:files_only_git_files')
    warnings += ['fuzzbox: g:files_only_git_files is no longer supported, use :FuzzyGitFiles command instead']
endif
if exists('g:files_respect_gitignore')
    warnings += ['fuzzbox: g:files_respect_gitignore is deprecated, gitignore is now respected by default']
    g:fuzzbox_files_respect_gitignore = g:files_respect_gitignore
endif
if exists('g:fuzzbox_files_ignore_file')
    warnings += ['fuzzbox: g:fuzzbox_files_ignore_file is deprecated, use g:fuzzbox_files_exclude_file instead']
    g:fuzzbox_files_exclude_file = g:fuzzbox_files_ignore_file
endif
if exists('g:fuzzbox_files_ignore_dir')
    warnings += ['fuzzbox: g:fuzzbox_files_ignore_dir is deprecated, use g:fuzzbox_files_exclude_dir instead']
    g:fuzzbox_files_exclude_dir = g:fuzzbox_files_ignore_dir
endif
if exists('g:fuzzbox_mru_project_only')
    warnings += ['fuzzbox: g:fuzzbox_mru_project_only is no longer supported, use :FuzzyMruCwd command instead']
endif

# Options
g:fuzzbox_enable_mappings = exists('g:fuzzbox_enable_mappings') ? g:fuzzbox_enable_mappings : 1
g:fuzzbox_respect_gitignore = exists('g:fuzzbox_respect_gitignore') ? g:fuzzbox_respect_gitignore : 1
g:fuzzbox_follow_symlinks = exists('g:fuzzbox_follow_symlinks') ? g:fuzzbox_follow_symlinks : 0
g:fuzzbox_include_hidden = exists('g:fuzzbox_include_hidden') ? g:fuzzbox_include_hidden : 1
g:fuzzbox_exclude_file = exists('g:fuzzbox_exclude_file')
    && type(g:fuzzbox_exclude_file) == v:t_list ? g:fuzzbox_exclude_file : ['*.swp', 'tags']
g:fuzzbox_exclude_dir = exists('g:fuzzbox_exclude_dir')
    && type(g:fuzzbox_exclude_dir) == v:t_list ? g:fuzzbox_exclude_dir : ['.git', '.hg', '.svn']
g:fuzzbox_ripgrep_options = exists('g:fuzzbox_ripgrep_options')
    && type(g:fuzzbox_ripgrep_options) == v:t_list ? g:fuzzbox_ripgrep_options : []

# window layout customization for particular selectors
# you can override it by setting g:fuzzbox_window_layout
# e.g. let g:fuzzbox_window_layout = { 'files': { 'preview': 0 } }
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
if exists('g:fuzzbox_window_layout') && type(g:fuzzbox_window_layout) == v:t_dict
    for [key, value] in items(windows)
        if has_key(g:fuzzbox_window_layout, key)
            windows[key] = extend(value, g:fuzzbox_window_layout[key])
        endif
    endfor
endif

highlight default link fuzzboxCursor Cursor
highlight default link fuzzboxNormal Normal
highlight default link fuzzboxBorder Normal
highlight default link fuzzboxCounter NonText
highlight default link fuzzboxMatching Special
highlight default link fuzzboxPreviewMatch CurSearch

import autoload '../autoload/fuzzbox/utils/launcher.vim'
import autoload '../autoload/fuzzbox/utils/helpers.vim'

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
command! -nargs=0 FuzzyHelps Warn('fuzzbox: FuzzyHelps command is deprecated, use FuzzyHelp instead') | FuzzyHelp
command! -nargs=0 FuzzyMRUFiles Warn('fuzzbox: FuzzyMRUFiles command is deprecated, use FuzzyMru instead') | FuzzyMru

# Hack to only show a single line warning when startng the selector
# Avoids showing warnings on Vim startup and does not break selector
if len(warnings) > 0
    g:__fuzzbox_warnings_found = 1
    command! -nargs=0 FuzzyShowWarnings for warning in warnings | echo warning | endfor
endif

if g:fuzzbox_enable_mappings
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
augroup fuzzboxCompat
  au!
  autocmd VimEnter * runtime! compat/fuzzbox.vim
augroup END
