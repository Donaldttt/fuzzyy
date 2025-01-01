vim9script

import autoload 'utils/selector.vim'

def Select(wid: number, result: list<any>)
    var command = result[0]
    var info = split(execute(':filter /\<' .. command .. '\>/ command ' .. command), '\n')[-1]
    var nargs = split(matchstr(info, '\<' .. command .. '\>\s\+\S'), '\s\+')[-1]
    call feedkeys(':' .. command .. ' ', 'n')
    if nargs == "0"
        call feedkeys("\<CR>", 'n')
    endif
enddef

export def Start(windows: dict<any>)
    var li: list<string> = getcompletion('', 'command')
    var wids = selector.Start(li, {
        select_cb:  function('Select'),
        width: windows.width,
    })
enddef
