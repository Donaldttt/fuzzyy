vim9script

scriptencoding utf-8

import autoload '../utils/selector.vim'
import autoload '../utils/popup.vim'

var raw_lines: list<string>
var file_type: string
var file_name: string

def Select(wid: number, result: list<any>)
    var linenr = str2nr(split(result[0], ':')[0])
    exe 'norm! ' .. linenr .. 'G'
    norm! zz
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if result == ''
        popup_settext(wid, '')
        return
    endif
    var preview_bufnr = winbufnr(wid)
    var lnum = split(trim(result[0 : 10]), ' ')[0]
    if popup_getpos(wid).lastline == 1
        popup_setoptions(wid, {title: fnamemodify(file_name, ':t')})
        popup_settext(wid, raw_lines)
        setbufvar(preview_bufnr, '&syntax', file_type)
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
enddef

def SelectTab(wid: number, result: list<any>)
    if !empty(result) && !empty(result[0])
        var line = str2nr(split(result[0], '│')[0])
        exe 'tabnew ' .. fnameescape(file_name)
        exe 'norm! ' .. line .. 'G'
        exe 'norm! zz'
    endif
enddef

def SelectVSplit(wid: number, result: list<any>)
    if !empty(result) && !empty(result[0])
        var line = str2nr(split(result[0], '│')[0])
        exe 'vsplit ' .. fnameescape(file_name)
        exe 'norm! ' .. line .. 'G'
        exe 'norm! zz'
    endif
enddef

def SelectSplit(wid: number, result: list<any>)
    if !empty(result) && !empty(result[0])
        var line = str2nr(split(result[0], '│')[0])
        exe 'split ' .. fnameescape(file_name)
        exe 'norm! ' .. line .. 'G'
        exe 'norm! zz'
    endif
enddef

def SelectQuickFix(wid: number, result: list<any>)
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
    selector.ReplaceSelectCb(function('SelectVSplit'))
    selector.CloseWithSelection()
enddef

def SetSplitClose()
    selector.ReplaceSelectCb(function('SelectSplit'))
    selector.CloseWithSelection()
enddef

def SetTabClose()
    selector.ReplaceSelectCb(function('SelectTab'))
    selector.CloseWithSelection()
enddef

def SetQuickFixClose()
    selector.ReplaceSelectCb(function('SelectQuickFix'))
    selector.CloseWithSelection()
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

    var wids = selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        key_callbacks: split_edit_callbacks,
    }))

    if len(get(opts, 'search', '')) > 0
        popup.SetPrompt(opts.search)
    endif
enddef
