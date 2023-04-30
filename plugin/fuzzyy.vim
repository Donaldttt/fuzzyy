if !has('vim9script') ||  v:version < 900
  finish
endif
vim9script

if exists("g:loaded_fuzzyy")
  finish
endif
g:loaded_fuzzyy = 1

import '../autoload/utils/popup.vim'

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
    g:fuzzy#files#init()
    g:fuzzy#ag#init()
    g:fuzzy#infile#init()
    g:fuzzy#colors#init()
endif
