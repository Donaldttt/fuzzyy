vim9script

import autoload './utils/selector.vim'

var tag_list: list<string>

def ParseResult(result: string): list<any>
    var [tag, path, pattern] = result->split("\t")[0 : 2]
    pattern = pattern->substitute('^\/', '', '')->substitute('\M\/;\?"\?$', '', '')
    return [tag, path, pattern]
enddef

def EscQuotes(str: string): string
    return substitute(str, "'", "''", 'g')
enddef

def Select(wid: number, result: list<any>)
    var [tag, path, pattern] = ParseResult(result[0])
    if filereadable(path)
        selector.MoveToUsableWindow()
        exe 'edit ' .. path
        execute("silent! exec 'norm! ' .. search('\\M" .. EscQuotes(pattern) .. "', 'w')")
        exe 'norm! zz'
    endif
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
    win_execute(preview_wid, 'syntax clear')
    var [tag, path, pattern] = ParseResult(result)
    if !filereadable(path)
        if result == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, path .. ' not found')
        endif
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    noautocmd call popup_settext(preview_wid, readfile(path))
    win_execute(preview_wid, 'silent! doautocmd filetypedetect BufNewFile ' .. path)
    noautocmd win_execute(preview_wid, 'silent! setlocal nospell nolist')
    win_execute(preview_wid, "silent! exec 'norm! ' .. search('\\M" .. EscQuotes(pattern) .. "', 'w')")
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
    selector.FuzzySearchAsync(tag_list, pattern, 200, function('AsyncCb'))
enddef

export def Start(opts: dict<any> = {})
    tag_list = []
    for path in tagfiles()
        var lines = readfile(path)
        tag_list += lines[match(lines, '^[^!]') : -1]
    endfor

    var wids = selector.Start(tag_list, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        input_cb: function('Input'),
    }))
enddef
