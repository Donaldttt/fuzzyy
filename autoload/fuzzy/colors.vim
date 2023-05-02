vim9script

import autoload 'utils/selector.vim'

var old_color: string
var old_bg: string
var menu_wid: number

def GetColors(): list<string>
   return uniq(sort(map(
     globpath(&runtimepath, "colors/*.vim", 0, 1),
     'fnamemodify(v:val, ":t:r")'
   )))
enddef

def Preview(wid: number, result: dict<any>)
    var color = result.cursor_item
    &bg = old_bg
    execute 'colorscheme ' .. color
enddef

def Close(wid: number, result: dict<any>)
    if !has_key(result, 'selected_item')
        &bg = old_bg
        execute 'colorscheme ' .. old_color
    else
        var color = result.selected_item
        var bg: string
        if color =~# 'light$'
            bg = 'light'
        else
            bg = &bg
        endif
        g:theme#setColor(bg, color)
    endif
enddef

export def ColorsStart()
    old_color = execute('colo')[1 :]
    old_bg = &bg
    var colors = GetColors()

    var winds = selector.Start(colors, {
        preview: 0,
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        reverse_menu: 1,
        width: 0.25,
        xoffset: 0.7,
        scrollbar: 0,
        preview_ratio: 0.7
    })
    menu_wid = winds[0]
enddef
