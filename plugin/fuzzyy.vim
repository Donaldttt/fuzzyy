if !has('vim9script') ||  v:version < 900
  finish
endif
vim9script

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

import autoload '../autoload/utils/popup.vim'
import autoload '../autoload/fuzzy/commands.vim'
import autoload '../autoload/fuzzy/ag.vim'
import autoload '../autoload/fuzzy/files.vim'
import autoload '../autoload/fuzzy/helps.vim'

def g:PopupSelection(opts: dict<any>): list<number>
    return popup.PopupSelection(opts)
enddef

def g:MenuSetHl(name: string, wid: number, hl_list_raw: list<any>): number
    return popup.MenuSetHl(name, wid, hl_list_raw)
enddef

def g:MenuSetText(wid: number, text_list: list<string>)
    popup.MenuSetText(wid, text_list)
enddef

if !has('nvim')
    g:fuzzy#infile#init()
    g:fuzzy#colors#init()
endif

command! -nargs=0 FuzzyCommands commands.CommandsStart()
nnoremap <silent> <leader>fi :FuzzyCommands<CR>

command! -nargs=0 FuzzyAg ag.AgStart()
nnoremap <silent> <leader>fr :FuzzyAg<CR>

command! -nargs=0 FuzzyFiles files.FilesStart()
nnoremap <silent> <leader>ff :FuzzyFiles<CR>

command! -nargs=0 FuzzyHelps helps.HelpsStart()
nnoremap <silent> <leader>fd :FuzzyHelps<CR>
