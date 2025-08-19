vim9script

scriptencoding utf-8

import autoload '../utils/selector.vim'
import autoload '../utils/previewer.vim'
import autoload '../utils/popup.vim'
import autoload '../utils/helpers.vim'

def Select(wid: number, result: string)
    var nr = str2nr(split(result, '│')[0])
    helpers.MoveToUsableWindow()
    exe 'cc!' .. nr
enddef

def ParseResult(result: string): list<any>
    var idx = str2nr(split(result, '│')[0]) - 1
    var item = getqflist()[idx]
    var fname: string
    if item->has_key('filename')
        fname = item.filename
    elseif item->has_key('bufnr')
        fname = bufname(item.bufnr)
    endif
    var lnum = item->get('lnum', 1)
    return [fname, lnum]
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if result == ''
        previewer.PreviewText(wid, '')
        return
    endif
    var [fname, lnum] = ParseResult(result)
    previewer.PreviewFile(wid, fname)
    win_execute(wid, 'norm! ' ..  lnum .. 'G')
    win_execute(wid, 'norm! zz')
enddef

def OpenFileTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    exe 'tabnew ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    exe 'vsplit ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    exe 'split ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

export def Start(opts: dict<any> = {})
    if getqflist({nr: '$'}).nr == 0
        echohl ErrorMsg | echo "Quickfix list is empty" | echohl None
        return
    endif

    # copied from scope.vim, thanks @girishji
    var size = getqflist({size: 0}).size
    var fmt = ' %' ..  len(string(size)) .. 'd │ '
    var lines = getqflist()->mapnew((idx, v) => {
        var fname: string
        if v->has_key('filename')
            fname = v.filename
        elseif v->has_key('bufnr')
            fname = bufname(v.bufnr)
        endif
        var text = v->get('text', '')
        var lnum = v->get('lnum', 0)
        if lnum > 0
            var col = v->get('col', 0)
            if col > 0
                return printf($"{fmt}%s:%d:%d:%s", idx + 1, fname, lnum, col, text)
            else
                return printf($"{fmt}%s:%d:%s", idx + 1, fname, lnum, text)
            endif
        endif
        return printf($"{fmt}%s:%s", idx + 1, fname, text)
    })

    echo getqflist({title: 0}).title

    selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
        }
    }))
enddef
