vim9script

import autoload 'utils/selector.vim'

def Select(wid: number, result: list<any>)
    var command = result[0]
    var info = split(execute(':filter /\<' .. command .. '\>/ command ' .. command), '\n')[-1]
    var nargs = split(matchstr(info, '\<' .. command .. '\>\s\+\S'), '\s\+')[-1]
    if nargs == "0"
        exe command
    else
        call feedkeys(':' .. command .. ' ', 'n')
    endif
enddef

export def Start()
    var li: list<string> = getcompletion('', 'command')
    var wids = selector.Start(li, {
        select_cb:  function('Select'),
        preview:  0,
        width:  0.4,
    })
enddef

