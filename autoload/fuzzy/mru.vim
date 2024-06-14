vim9script

import autoload '../utils/selector.vim'
import autoload '../utils/devicons.vim'
import autoload '../utils/mru.vim'

var mru_origin_list: list<string>
var devicon_char_width = devicons.GetDeviconCharWidth()
var cwd: string
var menu_wid: number

var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')

var mru_project_only = exists('g:fuzzyy_mru_project_only') ? g:fuzzyy_mru_project_only : 0

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if enable_devicons
        result = strcharpart(result, devicon_char_width + 1)
    endif
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    result = result == '' ? result : fnamemodify(result, ':p')
    if !filereadable(result)
        if result == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, result .. ' not found')
        endif
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    var fileraw = readfile(result, '', 70)
    var ext = fnamemodify(result, ':e')
    var ft = selector.GetFt(ext)
    popup_settext(preview_wid, fileraw)
    try
        setbufvar(preview_bufnr, '&syntax', ft)
    catch
    endtry
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        var path = result['selected_item']
        if enable_devicons
            path = strcharpart(path, devicon_char_width + 1)
        endif
        execute('edit ' .. path)
    endif
enddef

def ToggleScope()
    mru_project_only = mru_project_only ? 0 : 1
    var mru_list: list<string> = copy(mru_origin_list)
    if mru_project_only
        mru_list = filter(mru_list, (_, val) => {
            return stridx(val, cwd) >= 0
        })
    endif
    mru_list = reduce(mru_list, (acc, val) => {
            acc->add(fnamemodify(val, ':~:.'))
        return acc
    }, [])
    selector.UpdateMenu(mru_list, [], 1)
    popup_setoptions(menu_wid, {'title': len(mru_list)})
enddef

var key_callbacks = {
    "\<c-k>": function('ToggleScope'),
}

export def Start(windows: dict<any>, ...keyword: list<any>)
    cwd = getcwd()
    mru_origin_list = mru.MruGetFiles()
    var mru_list: list<string> = copy(mru_origin_list)
    if mru_project_only
        mru_list = filter(mru_list, (_, val) => {
            return stridx(val, cwd) >= 0
        })
    endif
    mru_list = reduce(mru_list, (acc, val) => {
            acc->add(fnamemodify(val, ':~:.'))
        return acc
    }, [])

    var wids = selector.Start(mru_list, {
        close_cb:  function('Close'),
        preview_cb:  function('Preview'),
        preview:  windows.preview,
        width: windows.width,
        preview_ratio: windows.preview_ratio,
        scrollbar: 0,
        enable_devicons: enable_devicons,
        key_callbacks: extend(key_callbacks, selector.split_edit_callbacks),
    })
    menu_wid = wids.menu
    popup_setoptions(menu_wid, {'title': len(mru_list)})
enddef
