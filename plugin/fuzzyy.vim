if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script noclear

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

g:enable_fuzzyy_keymaps = exists('g:enable_fuzzyy_keymaps') ? g:enable_fuzzyy_keymaps : 1
g:fuzzyy_buffers_exclude = exists('g:fuzzyy_buffers_exclude') ? g:fuzzyy_buffers_exclude
    : ['__vista__']

# window layout
# you can override it by setting g:fuzzyy_window_layout
# e.g. let g:fuzzyy_window_layout = { 'FuzzyFiles': { 'preview': 0 } }
# default value:
var windows = {
    FuzzyFiles: {
        preview: 1,         # 1 means enable preview window, 0 means disable
        preview_ratio: 0.5, # 0.5 means preview window will take 50% of the layout
        width: 0.8,         # 0.8 means total width of the layout will take 80% of the screen
    },
    FuzzyGrep: {
        preview: 1,
        preview_ratio: 0.5,
        width: 0.8,
    },
    FuzzyBuffers: {
        preview: 1,
        preview_ratio: 0.5,
        width: 0.8,
    },
    FuzzyMRUFiles: {
        preview: 1,
        preview_ratio: 0.5,
        width: 0.8,
    },
    FuzzyHighlights: {
        preview: 1,
        preview_ratio: 0.7,
        width: 0.8,
    },
}

if exists('g:fuzzyy_window_layout') && type(g:fuzzyy_window_layout) == v:t_dict
    for [key, value] in items(windows)
        if has_key(g:fuzzyy_window_layout, key)
            windows[key] = extend(value, g:fuzzyy_window_layout[key])
        endif
    endfor
endif

import autoload '../autoload/fuzzy/commands.vim'
import autoload '../autoload/fuzzy/grep.vim'
import autoload '../autoload/fuzzy/files.vim'
import autoload '../autoload/fuzzy/helps.vim'
import autoload '../autoload/fuzzy/colors.vim'
import autoload '../autoload/fuzzy/inbuffer.vim'
import autoload '../autoload/fuzzy/buffers.vim'
import autoload '../autoload/fuzzy/highlights.vim'
import autoload '../autoload/fuzzy/cmdhistory.vim'
import autoload '../autoload/fuzzy/mru.vim'

command! -nargs=? FuzzyGrep grep.Start(windows.FuzzyGrep, <f-args>)
command! -nargs=0 FuzzyFiles files.Start(windows.FuzzyFiles)
command! -nargs=0 FuzzyHelps helps.Start()
command! -nargs=0 FuzzyColors colors.Start()
command! -nargs=? FuzzyInBuffer inbuffer.Start(<f-args>)
command! -nargs=0 FuzzyCommands commands.Start()
command! -nargs=0 FuzzyBuffers buffers.Start(windows.FuzzyBuffers)
command! -nargs=0 FuzzyHighlights highlights.Start(windows.FuzzyHighlights)
command! -nargs=0 FuzzyGitFiles files.Start(windows.FuzzyFiles, 'git ls-files')
command! -nargs=0 FuzzyCmdHistory cmdhistory.Start()
command! -nargs=0 FuzzyMRUFiles mru.Start(windows.FuzzyMRUFiles)

if g:enable_fuzzyy_keymaps
    nnoremap <silent> <leader>fb :FuzzyInBuffer<CR>
    nnoremap <silent> <leader>fc :FuzzyColors<CR>
    nnoremap <silent> <leader>fd :FuzzyHelps<CR>
    nnoremap <silent> <leader>ff :FuzzyFiles<CR>
    nnoremap <silent> <leader>fi :FuzzyCommands<CR>
    nnoremap <silent> <leader>fr :FuzzyGrep<CR>
    nnoremap <silent> <leader>ft :FuzzyBuffers<CR>
    nnoremap <silent> <leader>fh :FuzzyHighlights<CR>
    nnoremap <silent> <leader>fm :FuzzyMRUFiles<CR>
endif
