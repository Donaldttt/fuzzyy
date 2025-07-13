vim9script

import autoload './utils/selector.vim'

var tag_table: dict<any>
var tag_files: list<string>
var menu_wid: number

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
    var tag_file = tag_files[tag_table[result][2]]
    # Note: forward slash path separator tested on Windows, works fine
    var doc_file = fnamemodify(tag_file, ':h') .. '/' .. tag_table[result][0]
    popup_settext(preview_wid, readfile(doc_file))
    popup_setoptions(preview_wid, {title: fnamemodify(doc_file, ':t')})
    var tag_name = substitute(tag_table[result][1], '\v^(\/\*)(.*)(\*)$', '\2', '')
    win_execute(preview_wid, "exec 'norm! ' .. search('\\m\\*" .. EscQuotes(tag_name) .. "\\*\\C', 'w')")
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
    popup_setoptions(menu_wid, {title: selector.total_results})
enddef

var async_tid: number
def Input(wid: number, args: dict<any>, ...li: list<any>)
    var pattern = args.str
    if pattern != ''
        async_tid = selector.FuzzySearchAsync(keys(tag_table), pattern, 200, function('AsyncCb'))
    else
        timer_stop(async_tid)
        selector.UpdateMenu(keys(tag_table), [])
        popup_setoptions(menu_wid, {title: len(keys(tag_table))})
    endif
enddef

def CloseCb(wid: number, args: dict<any>)
    if has_key(args, 'selected_item')
        var tag = args.selected_item
        var tag_data = tag_table[tag]
        try
            # try to open the file and jump to tag first, allows for edge cases
            # where duplicate tags exist and Fuzzyy finds the tag that Vim does
            # not consider "best" match, then previews one and opens the other
            exe ':help ' .. tag_data[0]
            exe ':tag ' .. tag_data[1]
        catch
            exe ':help ' .. tag
        endtry
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
enddef

export def Start(opts: dict<any> = {})
    tag_files = reverse(split(globpath(&runtimepath, 'doc/tags', 1), '\n'))
    var tab_table: dict<any>
    var file_index = 0
    for file in tag_files
        for line in readfile(file)
            var li = split(line)
            tag_table[li[0]] = [li[1], li[2], file_index]
        endfor
        file_index += 1
    endfor

    var wids = selector.Start(keys(tag_table), extend(opts, {
        preview_cb: function('Preview'),
        close_cb: function('CloseCb'),
        input_cb: function('Input'),
    }))
    menu_wid = wids.menu
    popup_setoptions(menu_wid, {title: len(tag_table)})
enddef
