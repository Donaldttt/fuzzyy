vim9script

import autoload 'utils/selector.vim'

const WIN_WIDTH = 0.8
var buf_dict: dict<any>

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if result == ''
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    var file = buf_dict[result][0]
    var lnum = buf_dict[result][2]
    if !filereadable(file)
        if file == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, file .. ' not found')
        endif
        return
    endif
    var bufnr = buf_dict[result][1]
    var ft = getbufvar(bufnr, '&filetype')
    var fileraw = readfile(file, '')
    var preview_bufnr = winbufnr(preview_wid)
    popup_settext(preview_wid, fileraw)
    try
        setbufvar(preview_bufnr, '&syntax', ft)
    catch
    endtry
    win_execute(preview_wid, 'norm! ' .. lnum .. 'G')
    win_execute(preview_wid, 'norm! zz')
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        var buf = result.selected_item
        var bufnr = buf_dict[buf][1]
        if bufnr != bufnr('$')
            execute 'buffer' bufnr
        endif
    endif
enddef

export def Start()
    var buf_data = getbufinfo({'buflisted': 1, 'bufloaded': 1}) 
    buf_dict = {}
    var bufs = reduce(buf_data, (acc, buf) => {
        var file = fnamemodify(buf.name, ":~:.")
        if len(file) > WIN_WIDTH / 2 * &columns
            file = pathshorten(file)
        endif
        acc[file] = [buf.name, buf.bufnr, buf.lnum]
        return acc
    }, buf_dict)
    var winds = selector.Start(keys(bufs), {
        preview_cb:  function('Preview'),
        close_cb:  function('Close'),
        width: WIN_WIDTH,
        dropdown: 0,
        preview:  1,
        scrollbar: 0,
    })
enddef
