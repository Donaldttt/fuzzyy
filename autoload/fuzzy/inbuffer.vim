vim9script

import autoload 'utils/selector.vim'
import autoload 'utils/popup.vim'

def Select(wid: number, result: list<any>)
    var linenr = str2nr(split(result[0], ':')[0])
    exe 'norm! ' .. linenr .. 'G'
    norm! zz
enddef

export def Start(windows: dict<any>, ...keyword: list<any>)
    var raw_lines = getline(1, '$')
    var max_line_len = len(string(len(raw_lines)))
    var lines = reduce(raw_lines,
       (a, v) => add(a, printf('%' .. max_line_len .. 'd:%s', len(a) + 1,  v)), [])

    var winds = selector.Start(lines, {
        select_cb: function('Select'),
        width: windows.width,
        height: windows.height,
    })

    if len(keyword) > 0
        popup.SetPrompt(keyword[0])
    endif
enddef
