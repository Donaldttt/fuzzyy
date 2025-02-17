vim9script

scriptencoding utf-8

import autoload './utils/selector.vim'
import autoload './utils/popup.vim'

var raw_lines: list<string>
var file_type: string
var file_name: string

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
    if result == ''
        popup_settext(preview_wid, '')
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    var lnum = split(trim(result[0 : 10]), ' ')[0]
    if popup_getpos(preview_wid).lastline == 1
        popup_settext(preview_wid, raw_lines)
        setbufvar(preview_bufnr, '&syntax', file_type)
    endif
    win_execute(preview_wid, 'norm! ' .. lnum .. 'G')
    win_execute(preview_wid, 'norm! zz')
enddef

def CloseTab(wid: number, result: dict<any>)
    if !empty(get(result, 'cursor_item', ''))
        var line = str2nr(split(result.cursor_item, '│')[0])
        exe 'tabnew ' .. fnameescape(file_name)
        exe 'norm! ' .. line .. 'G'
        exe 'norm! zz'
    endif
enddef

def CloseVSplit(wid: number, result: dict<any>)
    if !empty(get(result, 'cursor_item', ''))
        var line = str2nr(split(result.cursor_item, '│')[0])
        exe 'vsplit ' .. fnameescape(file_name)
        exe 'norm! ' .. line .. 'G'
        exe 'norm! zz'
    endif
enddef

def CloseSplit(wid: number, result: dict<any>)
    if !empty(get(result, 'cursor_item', ''))
        var line = str2nr(split(result.cursor_item, '│')[0])
        exe 'split ' .. fnameescape(file_name)
        exe 'norm! ' .. line .. 'G'
        exe 'norm! zz'
    endif
enddef

def CloseQuickFix(wid: number, result: dict<any>)
    var bufnr = winbufnr(wid)
    var lines: list<any>
    lines = reverse(getbufline(bufnr, 1, "$"))
    filter(lines, (_, val) => !empty(val))
    map(lines, (_, val) => {
        var [line, text] = split(val, '│')
        var dict = {
            filename: file_name,
            lnum: str2nr(line),
            col: 1,
            text: text }
        return dict
    })
    setqflist(lines)
    exe 'copen'
enddef

def SetVSplitClose()
    selector.ReplaceCloseCb(function('CloseVSplit'))
    selector.Close()
enddef

def SetSplitClose()
    selector.ReplaceCloseCb(function('CloseSplit'))
    selector.Close()
enddef

def SetTabClose()
    selector.ReplaceCloseCb(function('CloseTab'))
    selector.Close()
enddef

def SetQuickFixClose()
    selector.ReplaceCloseCb(function('CloseQuickFix'))
    selector.Close()
enddef

var split_edit_callbacks = {
    "\<c-v>": function('SetVSplitClose'),
    "\<c-s>": function('SetSplitClose'),
    "\<c-t>": function('SetTabClose'),
    "\<c-q>": function('SetQuickFixClose'),
}

export def Start(opts: dict<any> = {})
    raw_lines = getline(1, '$')
    file_type = &filetype
    file_name = expand('%')
    var max_line_len = len(string(line('$')))
    var lines = reduce(raw_lines,
       (a, v) => add(a, printf(' %' .. max_line_len .. 'd │ %s', len(a) + 1,  v)), [])

    var winds = selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        key_callbacks: split_edit_callbacks,
    }))

    if len(get(opts, 'search', '')) > 0
        popup.SetPrompt(opts.search)
    endif
enddef
