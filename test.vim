
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

let s:sep_pattern = '22'
def s:Reducer(pattern: string, acc: dict<any>, val: string): dict<any>
    var seq = matchstrpos(val, s:sep_pattern)
    if seq[1] == -1
        return acc
    endif

    var linecol = split(seq[0], ':')
    var line: number = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    endif
    var path = val[: seq[1] - 1]
    var str = val[seq[2] :]
    var colstart = max([col - 40, 0])
    var centerd_str = strpart(str, colstart, colstart + 40)
    var relative_path = path[len(s:cwd) + 1 :]

    var offset = len(relative_path) + len(seq[0]) + 1
    var match_cols: list<any>
    try
        match_cols = matchfuzzypos([str], pattern)[1]
    catch
        echoerr [val, centerd_str, pattern]
    endtry

    var final_str = relative_path .. seq[0] .. centerd_str
    var col_list = []
    if len(match_cols) > 0
        col_list = reduce(match_cols[0],  (a, v) => add(a, v + offset), [])
        acc.dict[final_str] = match_cols[0]
    endif
    var obj = {
     prefix: relative_path .. seq[0],
     centerd_str: centerd_str,
     col_list: col_list,
     }
    add(acc.objs, obj)
    add(acc.strs, final_str)
    add(acc.cols, col_list)
    return acc
enddef

call s:Reducer('f', {}, 'ss')
