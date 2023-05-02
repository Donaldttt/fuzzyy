if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

import autoload '../autoload/fuzzy/commands.vim'
import autoload '../autoload/fuzzy/ag.vim'
import autoload '../autoload/fuzzy/files.vim'
import autoload '../autoload/fuzzy/helps.vim'
import autoload '../autoload/fuzzy/colors.vim'
import autoload '../autoload/fuzzy/infile.vim'

command! -nargs=0 FuzzyCommands commands.CommandsStart()
nnoremap <silent> <leader>fi :FuzzyCommands<CR>

command! -nargs=0 FuzzyAg ag.AgStart()
nnoremap <silent> <leader>fr :FuzzyAg<CR>

command! -nargs=0 FuzzyFiles files.FilesStart()
nnoremap <silent> <leader>ff :FuzzyFiles<CR>

command! -nargs=0 FuzzyHelps helps.HelpsStart()
nnoremap <silent> <leader>fd :FuzzyHelps<CR>

command! -nargs=0 FuzzyColors colors.ColorsStart()
nnoremap <silent> <leader>fc :FuzzyColors<CR>

command! -nargs=0 FuzzyInfiles infile.InfileStart()
nnoremap <silent> <leader>fb :FuzzyInfiles<CR>

