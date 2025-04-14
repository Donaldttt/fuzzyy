
vim9script

import autoload './utils/selector.vim'

var hl_meta: dict<any>
var preview_wid: number

def Preview(wid: number, opts: dict<any>)
    if !has_key(hl_meta, opts.cursor_item)
        return
    endif
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var line = hl_meta[opts.cursor_item][0]
    win_execute(preview_wid, 'normal! ' .. line .. 'G')
    win_execute(preview_wid, 'normal! zz')
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        setreg('*', result.selected_item)
    endif
enddef

def TogglePreviewBg()
    var old = getwinvar(preview_wid, '&wincolor')
    if old == 'fuzzyyHighlights_whitebg'
        setwinvar(preview_wid, '&wincolor', 'Normal')
    else
        setwinvar(preview_wid, '&wincolor', 'fuzzyyHighlights_whitebg')
    endif
enddef

hi fuzzyyHighlights_whitebg ctermbg=white ctermfg=black guibg=white guifg=black
var key_callbacks = {
    "\<c-k>": function('TogglePreviewBg'),
}

export def Start(opts: dict<any> = {})
    var highlights_raw = substitute(execute('hi'), "\n", " ", "g") .. ' fuzzyy_dummyy xxx'
    var highlights: list<any> = []
    def Helper(s: any): number
        highlights->add(s)
        return 1
    enddef
    substitute(highlights_raw, '\zs[a-zA-Z0-9_.-]\+\s\+xxx[[:alnum:][:blank:]=#,]\{-}\ze\s\+\w\+\s*xxx',
        '\=Helper(submatch(0))', 'g')

    hl_meta = {}
    for idx in range(len(highlights))
        var hl_raw = highlights[idx]
        var xxxidx = hl_raw->match('xxx')
        var name = split(hl_raw)[0]
        hl_meta[name] = [idx + 1, xxxidx]
    endfor

    var wids = selector.Start(keys(hl_meta), extend(opts, {
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        key_callbacks: key_callbacks,
    }))

    preview_wid = wids.preview
    var menu_wid = wids.menu

    setwinvar(preview_wid, '&number', 0)
    # set preview buffer's content
    popup_settext(preview_wid, highlights)

    # add highlight to preview buffer
    for [hl, parts] in items(hl_meta)
        var line = parts[0]
        var xxxidx = parts[1]
        var mid = matchaddpos(hl, [[line, xxxidx + 1, 3]], 99, -1,  {window: preview_wid})
    endfor
enddef
