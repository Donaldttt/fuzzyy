vim9script

def Select(wid: number, result: list<any>)
    var command = result[0]
    exe command
enddef

export def CommandsStart()
    var li: list<string> = getcompletion('', 'command')
    var winds = g:utils#selector#start(li, {
        select_cb:  function('Select'),
        preview:  0,
        width:  0.4,
    })
enddef

