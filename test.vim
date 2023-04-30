
let s:popup_wins = {}
let s:popup_wins[1] = {}
let s:popup_wins[2] = {}

def s:MenuFilter()
enddef
def s:MenuSetText(...li: list<any>)
enddef
def s:MenuSetHl(...li: list<any>)
enddef
def s:PromptFilter()
enddef
def s:NewPopup(opts: dict<any>): any
    return [1, 1]
enddef

def s:Reducer(acc: list<string>, val: string): list<string>
    if isdirectory(val)
        return acc
    endif
    add(acc, val[s:cwdlen + 1 :])
    return acc
enddef

call s:Reducer([], 'ss')
