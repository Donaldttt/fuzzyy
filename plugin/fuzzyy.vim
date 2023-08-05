if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script noclear

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

g:enable_fuzzyy_keymaps = exists('g:enable_fuzzyy_keymaps') ? g:enable_fuzzyy_keymaps : 1
g:enable_fuzzyy_MRU_files = exists('g:enable_fuzzyy_MRU_files') ? g:enable_fuzzyy_MRU_files : 0

import autoload '../autoload/fuzzy/commands.vim'
import autoload '../autoload/fuzzy/ag.vim'
import autoload '../autoload/fuzzy/files.vim'
import autoload '../autoload/fuzzy/helps.vim'
import autoload '../autoload/fuzzy/colors.vim'
import autoload '../autoload/fuzzy/inbuffer.vim'
import autoload '../autoload/fuzzy/buffers.vim'
import autoload '../autoload/fuzzy/highlights.vim'

command! -nargs=? FuzzyGrep ag.AgStart(<f-args>)
command! -nargs=0 FuzzyFiles files.FilesStart()
command! -nargs=0 FuzzyHelps helps.HelpsStart()
command! -nargs=0 FuzzyColors colors.ColorsStart()
command! -nargs=? FuzzyInBuffer inbuffer.InBufferStart(<f-args>)
command! -nargs=0 FuzzyCommands commands.CommandsStart()
command! -nargs=0 FuzzyBuffers buffers.Start()
command! -nargs=0 FuzzyHighlights highlights.Start()

if g:enable_fuzzyy_MRU_files
    import autoload '../autoload/fuzzy/mru.vim'
    command! -nargs=0 FuzzyMRUFiles mru.Start()
    utils#mru#init()
endif

if g:enable_fuzzyy_keymaps
    nnoremap <silent> <leader>fb :FuzzyInBuffer<CR>
    nnoremap <silent> <leader>fc :FuzzyColors<CR>
    nnoremap <silent> <leader>fd :FuzzyHelps<CR>
    nnoremap <silent> <leader>ff :FuzzyFiles<CR>
    nnoremap <silent> <leader>fi :FuzzyCommands<CR>
    nnoremap <silent> <leader>fr :FuzzyGrep<CR>
    nnoremap <silent> <leader>ft :FuzzyBuffers<CR>
    nnoremap <silent> <leader>fh :FuzzyHighlights<CR>
    if g:enable_fuzzyy_MRU_files
        nnoremap <silent> <leader>fm :FuzzyMRUFiles<CR>
    endif
endif
