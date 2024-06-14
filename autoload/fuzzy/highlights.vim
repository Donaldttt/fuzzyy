
vim9script

import autoload '../utils/selector.vim'

var hl_meta: dict<any>

def Preview(wid: number, result: dict<any>)
    if !has_key(hl_meta, result.cursor_item)
        return
    endif
    var line = hl_meta[result.cursor_item][0]
    var preview_wid = selector.windows.preview
    win_execute(preview_wid, 'normal! ' .. line .. 'G')
    win_execute(preview_wid, 'normal! zz')
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        setreg('*', result.selected_item)
    endif
enddef

def TogglePreviewBg()
    var preview_wid = selector.windows.preview
    var old = getwinvar(preview_wid, '&wincolor')
    if old == 'fuzzyywhite'
        setwinvar(preview_wid, '&wincolor', 'Normal')
    else
        setwinvar(preview_wid, '&wincolor', 'fuzzyywhite')
    endif
enddef

hi fuzzyywhite ctermbg=white ctermfg=black guibg=white guifg=black
var key_callbacks = {
    "\<c-k>": function('TogglePreviewBg'),
}

def AddHighlight(preview_wid: number)
    var hl_meta_copy = copy(hl_meta)
    var hls = keys(hl_meta_copy)
    var parts = values(hl_meta_copy)
    var tid: number
    tid = timer_start(5, (timer) => {
        var hls_slice = hls[: 400]
        var parts_slice = parts[: 400]
        for i in range(len(hls_slice))
            var hl = hls_slice[i]
            var p = parts_slice[i]
            var line = p[0]
            var xxxidx = p[1]
            var mid = matchaddpos(hl, [[line, xxxidx + 1, 3]], 99, -1,  {window: preview_wid})
        endfor
        hls = hls[401 :]
        parts = parts[401 :]
        if len(hls) == 0
            timer_stop(tid)
        endif
    }, {repeat: -1})
enddef

export def Start(windows: dict<any>)
    var highlights_raw = substitute(execute('hi'), "\n", " ", "g") .. ' fuzzyy_dummyy xxx'
    var highlights: list<any> = []
    def Helper(s: any): number
        highlights->add(s)
        return 1
    enddef
    substitute(highlights_raw, '\zs\w\+\s\+xxx[[:alnum:][:blank:]=#,]\{-}\ze\s\+\w\+\s*xxx',
        '\=Helper(submatch(0))', 'g')

    hl_meta = {}
    for idx in range(len(highlights))
        var hl_raw = highlights[idx]
        var xxxidx = hl_raw->match('xxx')
        var name = split(hl_raw)[0]
        hl_meta[name] = [idx + 1, xxxidx]
    endfor

    var wids = selector.Start(keys(hl_meta), {
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        preview: windows.preview,
        width: windows.width,
        preview_ratio: windows.preview_ratio,
        scrollbar: 0,
        key_callbacks: key_callbacks,
    })

    var preview_wid = wids.preview
    var menu_wid = wids.menu

    setwinvar(preview_wid, '&number', 0)
    popup_setoptions(menu_wid, {'title': len(hl_meta)})
    # set preview buffer's content
    popup_settext(preview_wid, highlights)
    for [hl, parts] in items(hl_meta)
        # add highlight to preview buffer
        var line = parts[0]
        var xxxidx = parts[1]
        var mid = matchaddpos(hl, [[line, xxxidx + 1, 3]], 99, -1,  {window: preview_wid})
    endfor
    timer_start(1, (timer) => {
        var line = hl_meta[selector.MenuGetCursorItem()][0]
        win_execute(preview_wid, 'normal! ' .. line .. 'G')
        win_execute(preview_wid, 'normal! zz')
    })
enddef
