vim9script

scriptencoding utf-8

import autoload './utils/selector.vim'
import autoload './utils/popup.vim'

var raw_lines: list<string>
var file_type: string

def Select(wid: number, result: list<any>)
    var linenr = str2nr(split(result[0], ':')[0])
    exe 'norm! ' .. linenr .. 'G'
    norm! zz
enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    var preview_bufnr = winbufnr(preview_wid)
    var lnum = split(trim(result[0 : 10]), ' ')[0]
    if popup_getpos(preview_wid).lastline == 1
        popup_settext(preview_wid, raw_lines)
        setbufvar(preview_bufnr, '&syntax', file_type)
    endif
    win_execute(preview_wid, 'norm! ' .. lnum .. 'G')
    win_execute(preview_wid, 'norm! zz')
enddef

export def Start(opts: dict<any> = {})
    raw_lines = getline(1, '$')
    file_type = &filetype
    var max_line_len = len(string(line('$')))
    var lines = reduce(raw_lines,
       (a, v) => add(a, printf(' %' .. max_line_len .. 'd │ %s', len(a) + 1,  v)), [])

    var winds = selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview')
    }))

    if len(get(opts, 'search', '')) > 0
        popup.SetPrompt(opts.search)
    endif
enddef
