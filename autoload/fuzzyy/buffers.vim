vim9script

import autoload './utils/selector.vim'
import autoload './utils/devicons.vim'

var buf_dict: dict<any>
var key_callbacks: dict<any>
var _window_width: float

# Options
var exclude_buffers = exists('g:fuzzyy_buffers_exclude') ?
    g:fuzzyy_buffers_exclude : []

var keymaps = {
    'delete_file': "",
    'wipe_buffer': "",
    'close_buffer': "\<c-l>",
}
if exists('g:fuzzyy_buffers_keymap')
    keymaps->extend(g:fuzzyy_buffers_keymap, 'force')
endif

# deprecated delete_buffer keymap, renamed to delete_file, that's what is does
if has_key(keymaps, "delete_buffer") && !empty(keymaps.delete_buffer) && empty(keymaps.delete_file)
    keymaps.delete_file = keymaps.delete_buffer
endif

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
    var file: string
    var lnum: number
    file = buf_dict[result][0]
    lnum = buf_dict[result][2]
    if !filereadable(file)
        if file == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, file .. ' not found')
        endif
        return
    endif
    popup_setoptions(preview_wid, {title: fnamemodify(file, ':t')})
    var bufnr = buf_dict[result][1]
    var ft = getbufvar(bufnr, '&filetype')
    var fileraw = readfile(file)
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
            selector.MoveToUsableWindow(bufnr)
            execute 'buffer' bufnr
        endif
    endif
enddef

def GetBufList(): list<string>
    var buf_data = getbufinfo({buflisted: 1, bufloaded: 0})
    buf_dict = {}

    reduce(buf_data, (acc, buf) => {
        if index(exclude_buffers, fnamemodify(buf.name, ':t')) >= 0
        || buf.name == ''
            return acc
        endif
        var file = fnamemodify(buf.name, ":~:.")
        if len(file) > _window_width / 2 * &columns
            file = pathshorten(file)
        endif
        acc[file] = [buf.name, buf.bufnr, buf.lnum, buf.lastused]
        return acc
    }, buf_dict)

    var bufs = keys(buf_dict)->sort((a, b) => {
        return buf_dict[a][3] == buf_dict[b][3] ? 0 :
               buf_dict[a][3] <  buf_dict[b][3] ? 1 : -1
    })
    return bufs
enddef

def DeleteSelectedFile()
    var buf = selector.MenuGetCursorItem()
    var choice = confirm('Delete file ' .. buf .. '. Are you sure?', "&Yes\n&No")
    if choice != 1
        return
    endif
    delete(buf)
    WipeSelectedBuffer()
enddef

def DeleteSelectedBuffer(wipe: bool)
    var buf = selector.MenuGetCursorItem()
    if buf == ''
        return
    endif
    if wipe
        execute(':bwipeout ' .. buf)
    else
        execute(':bdelete ' .. buf)
    endif
    var li = GetBufList()
    selector.UpdateMenu(li, [])
    selector.UpdateList(li)
    selector.RefreshMenu()
enddef

def WipeSelectedBuffer()
    DeleteSelectedBuffer(true)
enddef

def CloseSelectedBuffer()
    DeleteSelectedBuffer(false)
enddef

key_callbacks[keymaps.delete_file] = function("DeleteSelectedFile")
key_callbacks[keymaps.wipe_buffer] = function("WipeSelectedBuffer")
key_callbacks[keymaps.close_buffer] = function("CloseSelectedBuffer")

export def Start(opts: dict<any> = {})
    # FIXME: allows the file path to be shortened to fit in the results window
    # without wrapping. Other file selectors do not do this, maybe remove it.
    _window_width = get(opts, 'width', 0.8)

    var wids = selector.Start(GetBufList(), extend(opts, {
        devicons: true,
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        key_callbacks: extend(selector.split_edit_callbacks, key_callbacks),
    }))
enddef
