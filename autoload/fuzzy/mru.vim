vim9script

import autoload 'utils/selector.vim'
import autoload 'utils/devicons.vim'

var devicon_char_width = devicons.GetDeviconCharWidth()

var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if enable_devicons
        result = strcharpart(result, devicon_char_width + 1)
    endif
    var preview_wid = opts.win_opts.partids['preview']
    result = fnamemodify(result, ':p')
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

export def Start(...keyword: list<any>)
    var cwd = getcwd()
    var mru_list = reduce(g:MruGetFiles(), (acc, val) => {
            acc->add(fnamemodify(val, ':~:.'))
        return acc
    }, [])

    var winds = selector.Start(mru_list, {
        close_cb:  function('Close'),
        preview_cb:  function('Preview'),
        preview:  1,
        scrollbar: 0,
        enable_devicons: enable_devicons,
    })
    var menu_wid = winds[0]
enddef
