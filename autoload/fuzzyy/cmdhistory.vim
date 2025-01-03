vim9script

import autoload './utils/selector.vim'
import autoload './utils/popup.vim'

def Select(wid: number, result: list<any>)
    var command = result[0]
    call feedkeys(':' .. command .. ' ', 'n')
    call feedkeys("\<CR>", 'n')
enddef

export def Start(windows: dict<any> = {})
    var cmds = split(execute("history"), '\n')[1 : ]

    # remove index of command history
    cmds = reduce(cmds,
        (a, v) => add(a, substitute(v, '\m^.*\d\+\s\+', '', '')), [])

    var wins = selector.Start(reverse(cmds), extend(windows, {
        select_cb: function('Select'),
    }))
    popup_setoptions(wins.menu, {'title': string(len(cmds))})
enddef
