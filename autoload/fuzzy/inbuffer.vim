vim9script

import autoload 'utils/selector.vim'
import autoload 'utils/popup.vim'

def Select(wid: number, result: list<any>)
    var linenr = str2nr(split(result[0], ':')[0])
    exe 'norm! ' .. linenr .. 'G'
    norm! zz
enddef

export def InBufferStart(...keyword: list<any>)
    var raw_lines = getline(1, '$')
    var max_line_len = len(string(len(raw_lines)))
    var lines = reduce(raw_lines,
       (a, v) => add(a, printf('%' .. max_line_len .. 'd:%s', len(a) + 1,  v)), [])

    var winds = selector.Start(lines, {
        select_cb:  function('Select'),
        preview:  0,
        reverse_menu:  0,
        width:  0.7
    })

    if len(keyword) > 0
        popup.SetPrompt(winds[1], keyword[0])
    endif
    # var menu_wid = winds[0]
    # var file = expand('%:p')
    # var ext = fnamemodify(file, ':e')
    # var ft = selector.GetFt(ext)
    # var menu_bufnr = winbufnr(menu_wid)
    # setbufvar(menu_bufnr, '&syntax', ft)
enddef
