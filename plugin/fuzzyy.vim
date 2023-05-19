if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

g:enable_fuzzyy_keymaps = exists('g:enable_fuzzyy_keymaps') ? g:enable_fuzzyy_keymaps : 1

import autoload '../autoload/fuzzy/commands.vim'
import autoload '../autoload/fuzzy/ag.vim'
import autoload '../autoload/fuzzy/files.vim'
import autoload '../autoload/fuzzy/helps.vim'
import autoload '../autoload/fuzzy/colors.vim'
import autoload '../autoload/fuzzy/inbuffer.vim'
import autoload '../autoload/fuzzy/buffers.vim'

command! -nargs=0 FuzzyGrep ag.AgStart()
command! -nargs=0 FuzzyFiles files.FilesStart()
command! -nargs=0 FuzzyHelps helps.HelpsStart()
command! -nargs=0 FuzzyColors colors.ColorsStart()
command! -nargs=0 FuzzyInBuffer inbuffer.InBufferStart()
command! -nargs=0 FuzzyCommands commands.CommandsStart()
command! -nargs=0 FuzzyBuffers buffers.Start()

if g:enable_fuzzyy_keymaps
    nnoremap <silent> <leader>fb :FuzzyInBuffer<CR>
    nnoremap <silent> <leader>fc :FuzzyColors<CR>
    nnoremap <silent> <leader>fd :FuzzyHelps<CR>
    nnoremap <silent> <leader>ff :FuzzyFiles<CR>
    nnoremap <silent> <leader>fi :FuzzyCommands<CR>
    nnoremap <silent> <leader>fr :FuzzyGrep<CR>
    nnoremap <silent> <leader>ft :FuzzyBuffers<CR>
endif
