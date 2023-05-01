vim9script

import autoload 'utils/selector.vim'

def Select(wid: number, result: list<any>)
    var command = result[0]
    exe command
enddef

export def CommandsStart()
    var li: list<string> = getcompletion('', 'command')
    var winds = selector.Start(li, {
        select_cb:  function('Select'),
        preview:  0,
        width:  0.4,
    })
enddef

