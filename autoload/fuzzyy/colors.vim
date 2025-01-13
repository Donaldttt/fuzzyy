vim9script

import autoload './utils/selector.vim'

var old_color: string
var old_bg: string

def GetColors(): list<string>
   return uniq(sort(map(
     globpath(&runtimepath, "colors/*.vim", 0, 1),
     'fnamemodify(v:val, ":t:r")'
   )))
enddef

def Preview(wid: number, result: dict<any>)
    var color = result.cursor_item
    &bg = old_bg
    noa execute 'colorscheme ' .. color
enddef

def Close(wid: number, result: dict<any>)
    if !has_key(result, 'selected_item')
        noa &bg = old_bg
        execute 'colorscheme ' .. old_color
    else
        var color = result.selected_item
        var bg: string
        if color =~# 'light$'
            noa &bg = 'light'
        endif
        execute 'colorscheme ' .. color
    endif
enddef

export def Start(opts: dict<any> = {})
    old_color = execute('colo')[1 :]
    old_bg = &bg
    var colors = GetColors()

    var wids = selector.Start(colors, extend(opts, {
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        preview: 0
    }))
enddef
