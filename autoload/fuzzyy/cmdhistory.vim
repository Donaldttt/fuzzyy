vim9script

import autoload './utils/selector.vim'
import autoload './utils/popup.vim'

def Select(wid: number, result: list<any>)
    var command = result[0]
    feedkeys(':' .. command .. "\<CR>", 'n')
enddef

export def Start(opts: dict<any> = {})
    var cmds = split(execute("history"), '\n')[1 : ]

    # remove index of command history
    cmds = reduce(cmds,
        (a, v) => add(a, substitute(v, '\m^.*\d\+\s\+', '', '')), [])

    selector.Start(reverse(cmds), extend(opts, {
        select_cb: function('Select'),
        preview: 0
    }))
enddef
