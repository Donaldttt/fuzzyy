vim9script

import autoload './utils/selector.vim'

var update_tid: number
var tag_table: dict<any>
var tag_files: list<string>
var menu_wid: number
var file_lines: list<string>
var cur_pattern: string

def Tags(): dict<any>
    var sorted = sort(split(globpath(&runtimepath, 'doc/tags', 1), '\n'))
    tag_files = uniq(sorted)
    var result: dict<any> = {}
    var file_index = 0
    for file in tag_files
        for line in readfile(file)
            file_lines += [ line .. ' ' .. file_index ]
        endfor
        file_index += 1
    endfor
    reduce(file_lines[: 1000], (acc, val) => {
        var li = split(val)
        acc[li[0]] = [li[1], li[2], li[3]]
        return acc
    }, result)
    file_lines = file_lines[1001 :]

    return result
enddef

def EscQuotes(str: string): string
    return substitute(str, "'", "''", 'g')
enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    if result == ''
        popup_settext(preview_wid, '')
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    setbufvar(preview_bufnr, '&syntax', 'help')
    var tag_file = tag_files[str2nr(tag_table[result][2])]
    # Note: forward slash path separator tested on Windows, works fine
    var doc_file = fnamemodify(tag_file, ':h') .. '/' .. tag_table[result][0]
    popup_settext(preview_wid, readfile(doc_file))
    var tag_name = substitute(tag_table[result][1], '\v^(\/\*)(.*)(\*)$', '\2', '')
    win_execute(preview_wid, "exec 'norm! ' .. search('\\m\\*" .. EscQuotes(tag_name) .. "\\*', 'w')")
    win_execute(preview_wid, 'norm! zz')
enddef

def AsyncCb(result: list<any>)
    var strs = []
    var hl_list = []
    var idx = 1
    for item in result
        add(strs, item[0])
        hl_list += reduce(item[1], (acc, val) => {
            add(acc, [idx] + val)
            return acc
        }, [])
        idx += 1
    endfor
    selector.UpdateMenu(strs, hl_list)
enddef

def Input(wid: number, args: dict<any>, ...li: list<any>)
    var pattern = args.str
    cur_pattern = pattern
    selector.FuzzySearchAsync(keys(tag_table), pattern, 200, function('AsyncCb'))
enddef

var last_pattern: string
def UpdateMenu(...args: list<any>)
    const STEP = 1000
    if len(tag_files) == 0
        timer_stop(update_tid)
        return
    endif
    reduce(file_lines[: STEP], (acc, val) => {
        var li = split(val)
        acc[li[0]] = [li[1], li[2], li[3]]
        return acc
    }, tag_table)
    file_lines = file_lines[STEP + 1 :]

    if cur_pattern != last_pattern
        var [ret, hl_list] = selector.FuzzySearch(keys(tag_table), cur_pattern, 1000)
        selector.UpdateMenu(ret, hl_list)
        last_pattern = cur_pattern
    endif
enddef

def CloseCb(wid: number, args: dict<any>)
    if has_key(args, 'selected_item')
        var tag = args.selected_item
        exe ':help ' .. tag
    else
        var tabnr = tabpagenr()
        var wins = gettabinfo(tabnr)[0].windows
        for win in wins
            var bufnr = winbufnr(win)
            if getbufvar(bufnr, '&buftype') == 'help'
                win_execute(win, ':q')
                break
            endif
        endfor
    endif
    timer_stop(update_tid)
enddef

export def Start(opts: dict<any> = {})
    tag_files = []
    file_lines = []
    cur_pattern = ''
    tag_table = Tags()
    last_pattern = ''
    var wids = selector.Start(keys(tag_table), extend(opts, {
        preview_cb: function('Preview'),
        close_cb: function('CloseCb'),
        input_cb: function('Input'),
    }))
    menu_wid = wids.menu
    update_tid = timer_start(20, function('UpdateMenu'), {repeat: -1})
enddef
