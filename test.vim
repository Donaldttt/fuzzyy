
let s:popup_wins = {}
let s:popup_wins[1] = {}
let s:popup_wins[2] = {}

def MenuSethl(name: string, wid: number, hl_list_raw: list<any>): number
    const hl = 'Error'
    if !has_key(s:popup_wins, wid)
        return -1
    endif
    var hl_list = hl_list_raw[: 70]

    var textrows = popup_getpos(wid).height - 2
    var height = max([len(hl_list_raw), textrows])
    if s:popup_wins[wid].reverse_menu
        hl_list = reduce(hl_list_raw, (acc, v) => add(acc, [height - v[0] + 1, v[1]]), [])
    endif

    var his = []
    for hlpos in hl_list
        var line = hlpos[0]
        var col_list = hlpos[1]
        if type(col_list) == v:t_list
            for col in col_list
                add(his, [line, col])
            endfor
        elseif type(col_list) == v:t_number
            if col_list > 0
                add(his, [line, col_list])
            endif
        endif
    endfor
    if has_key(s:popup_wins[wid]['highlights'], name) &&
        s:popup_wins[wid]['highlights'][name] != -1
        matchdelete(s:popup_wins[wid]['highlights'][name], wid)
        remove(s:popup_wins[wid]['highlights'], name)
    endif
    # pass empty list to matchaddpos will cause error
    if len(his) == 0
        return -1
    endif
    var mid = matchaddpos(hl, his, 10, -1,  {'window': wid})
    s:popup_wins[wid]['highlights'][name] = mid
    return mid
enddef


call MenuSethl('s', 3, [])

