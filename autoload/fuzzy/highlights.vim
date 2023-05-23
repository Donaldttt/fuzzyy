
vim9script

import autoload 'utils/selector.vim'

var hl_meta: dict<any>
var preview_win: number

def Preview(wid: number, result: dict<any>)
    if !has_key(hl_meta, result.cursor_item)
        return
    endif
    var line = hl_meta[result.cursor_item][0]
    win_execute(preview_win, 'normal! ' .. line .. 'G')
    win_execute(preview_win, 'normal! zz')
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        setreg('*', result.selected_item)
    endif
enddef

def TogglePreviewBg()
    var old = getwinvar(preview_win, '&wincolor')
    if old == 'fuzzyywhite'
        setwinvar(preview_win, '&wincolor', 'Normal')
    else
        setwinvar(preview_win, '&wincolor', 'fuzzyywhite')
    endif
enddef

hi fuzzyywhite ctermbg=white ctermfg=black guibg=white guifg=black
var key_callbacks = {
    "\<c-k>": function('TogglePreviewBg'),
}
export def Start()
    var highlights_raw = substitute(execute('hi'), "\n", " ", "g")
    var highlights: list<any> = []
    def Helper(s: any): number
        highlights->add(s)
        return 1
    enddef
    substitute(highlights_raw, '\zs\w\+\s\+xxx[[:alnum:][:blank:]=#,]\{-}\ze\s*\w\+\s*xxx',
        '\=Helper(submatch(0))', 'g')

    hl_meta = {}
    for idx in range(len(highlights))
        var hl_raw = highlights[idx]
        var xxxidx = hl_raw->match('xxx')
        var name = split(hl_raw)[0]
        hl_meta[name] = [idx + 1, xxxidx]
    endfor

    var menu_wid: number
    [menu_wid, _, preview_win] = selector.Start(keys(hl_meta), {
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        preview: 1,
        width: 0.8,
        scrollbar: 0,
        preview_ratio: 0.7,
        key_callbacks: key_callbacks,
    })

    setwinvar(preview_win, '&number', 0)
    # setwinvar(preview_win, '&wincolor', 'fuzzyywhite')
    popup_setoptions(menu_wid, {'title': len(hl_meta)})
    # set preview buffer's content
    popup_settext(preview_win, highlights)
    for [hl, parts] in items(hl_meta)
        # add highlight to preview buffer
        var line = parts[0]
        var xxxidx = parts[1]
        var mid = matchaddpos(hl, [[line, xxxidx + 1, 3]], 99, -1,  {window: preview_win})
    endfor
enddef
