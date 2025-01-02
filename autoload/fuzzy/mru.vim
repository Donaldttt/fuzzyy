vim9script

import autoload 'utils/selector.vim'
import autoload 'utils/devicons.vim'

var mru_origin_list: list<string>
var devicon_char_width = devicons.GetDeviconCharWidth()
var mru_cwd: string
var mru_cwd_only: bool
var menu_wid: number

var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')

if exists('g:fuzzyy_mru_project_only') && g:fuzzyy_mru_project_only
    echo 'fuzzyy: g:fuzzyy_mru_project_only is no longer supported, use :FuzzyMruCwd command instead'
endif

# Options
var file_exclude = exists('g:fuzzyy_mru_exclude_file')
    && type(g:fuzzyy_mru_exclude_file) == v:t_list ?
    g:fuzzyy_mru_exclude_file : g:fuzzyy_exclude_file
var dir_exclude = exists('g:fuzzyy_mru_exclude_dir')
    && type(g:fuzzyy_mru_exclude_dir) == v:t_list ?
    g:fuzzyy_mru_exclude_dir : g:fuzzyy_exclude_dir

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
    noautocmd call popup_settext(preview_wid, fileraw)
    win_execute(preview_wid, 'silent! doautocmd filetypedetect BufNewFile ' .. result)
    noautocmd win_execute(preview_wid, 'silent! setlocal nospell nolist')
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        var path = result['selected_item']
        if enable_devicons
            path = strcharpart(path, devicon_char_width + 1)
        endif
        selector.MoveToUsableWindow()
        exe 'edit ' .. path
    endif
enddef

def ToggleScope()
    mru_cwd_only = mru_cwd_only ? 0 : 1
    var mru_list: list<string> = copy(mru_origin_list)
    if mru_cwd_only
        mru_list = filter(mru_list, (_, val) => {
            return stridx(fnamemodify(val, ':p'), mru_cwd) >= 0
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

export def Start(windows: dict<any>, cwd: string = '')
    mru_cwd = empty(cwd) ? getcwd() : cwd
    mru_cwd_only = !empty(cwd)
    # sorted files from buffers opened during this session, including unlisted
    var mru_buffers = split(execute('buffers! t'), '\n')->map((_, val) => {
            var bufnumber = str2nr(matchstr(val, '\M\s\*\(\d\+\)'))
            if match(val, 'line 0$') == -1 # opened files have buffer line >= 1
                return fnamemodify(bufname(bufnumber), ':p')
            else
                return ''
            endif
        })->filter((_, val) => filereadable(val))
    # oldfiles that are not already included in buffers from this session
    var mru_oldfiles = copy(v:oldfiles)->map((_, val) => {
            return fnamemodify(expand(val), ':p')
        })->filter((_, val) => {
            return filereadable(val) && index(mru_buffers, val) == -1
        })
    mru_origin_list = mru_buffers + mru_oldfiles
    filter(mru_origin_list, (_, val) => {
        for dir in dir_exclude
            if val =~# glob2regpat('**/' .. dir .. '/**')
                return false
            endif
        endfor
        for glob in file_exclude
            if fnamemodify(val, ':t') =~# glob2regpat(glob)
                return false
            endif
        endfor
        return true
    })
    var mru_list: list<string> = copy(mru_origin_list)
    if mru_cwd_only
        mru_list = filter(mru_list, (_, val) => {
            return stridx(fnamemodify(val, ':p'), mru_cwd) >= 0
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
        preview_ratio: windows.preview_ratio,
        width: windows.width,
        height: windows.height,
        enable_devicons: enable_devicons,
        key_callbacks: extend(key_callbacks, selector.split_edit_callbacks),
    })
    menu_wid = wids.menu
    popup_setoptions(menu_wid, {'title': len(mru_list)})
enddef
