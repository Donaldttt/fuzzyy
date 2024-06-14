vim9script

import autoload '../utils/selector.vim'
import autoload '../utils/popup.vim'

def Select(wid: number, result: list<any>)
    exe ":leg " .. result[0]
enddef

export def Start()
    var cmds = split(execute("history"), '\n')[1 : ]

    # remove index of command history
    cmds = reduce(cmds,
       (a, v) => add(a, join(split(v)[1 : ])), [])

    var wins = selector.Start(cmds, {
        select_cb:  function('Select'),
        preview:  0,
        reverse_menu:  0,
        width:  0.6
    })

    popup_setoptions(wins.menu, {'title': string(len(cmds))})
enddef
