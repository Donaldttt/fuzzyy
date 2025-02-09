vim9script

import autoload './utils/selector.vim'
import autoload './utils/devicons.vim'

var mru_origin_list: list<string>
var devicon_char_width = devicons.GetDeviconCharWidth()
var cwd: string
var cwd_only: bool
var cwdlen: number
var menu_wid: number

var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')

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
    win_execute(preview_wid, 'syntax clear')
    var path = cwd_only ? cwd .. '/' .. result : result
    path = path == '' ? path : fnamemodify(path, ':p')
    if !filereadable(path)
        if path == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, result .. ' not found')
        endif
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    if selector.IsBinary(path)
        noautocmd popup_settext(preview_wid, 'Cannot preview binary file')
    else
        var content = readfile(path)
        noautocmd popup_settext(preview_wid, content)
        setwinvar(preview_wid, '&filetype', '')
        win_execute(preview_wid, 'silent! doautocmd filetypedetect BufNewFile ' .. path)
        noautocmd win_execute(preview_wid, 'silent! setlocal nospell nolist')
        if empty(getwinvar(preview_wid, '&filetype')) || getwinvar(preview_wid, '&filetype') == 'conf'
            var modelineft = selector.FTDetectModelines(content)
            if !empty(modelineft)
                win_execute(preview_wid, 'set filetype=' .. modelineft)
            endif
        endif
    endif
    win_execute(preview_wid, 'norm! gg')
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        var path = result['selected_item']
        if enable_devicons
            path = strcharpart(path, devicon_char_width + 1)
        endif
        selector.MoveToUsableWindow()
        if cwd_only
            exe 'edit ' cwd .. '/' .. fnameescape(path)
        else
            exe 'edit ' .. fnameescape(path)
        endif
    endif
enddef

def ToggleScope()
    cwd_only = cwd_only ? 0 : 1
    var mru_list: list<string> = copy(mru_origin_list)
    if cwd_only
        mru_list = filter(mru_list, (_, val) => {
            return stridx(fnamemodify(val, ':p'), cwd) >= 0
        })
        mru_list = reduce(mru_list, (acc, val) => {
            acc->add(strpart(fnamemodify(val, ':p'), len(cwd) + 1))
            return acc
        }, [])
    else
        mru_list = reduce(mru_list, (acc, val) => {
            acc->add(fnamemodify(val, ':~:.'))
            return acc
        }, [])
    endif
    selector.UpdateMenu(mru_list, [], 1)
    popup_setoptions(menu_wid, {title: len(mru_list)})
enddef

var key_callbacks = {
    "\<c-k>": function('ToggleScope'),
}

export def Start(opts: dict<any> = {})
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    cwd_only = len(get(opts, 'cwd', '')) > 0
    cwdlen = len(cwd)
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
    if cwd_only
        mru_list = filter(mru_list, (_, val) => {
            return stridx(fnamemodify(val, ':p'), cwd) >= 0
        })
        mru_list = reduce(mru_list, (acc, val) => {
            acc->add(strpart(fnamemodify(val, ':p'), cwdlen + 1))
            return acc
        }, [])
    else
        mru_list = reduce(mru_list, (acc, val) => {
            acc->add(fnamemodify(val, ':~:.'))
            return acc
        }, [])
    endif

    var wids = selector.Start(mru_list, extend(opts, {
        close_cb: function('Close'),
        preview_cb: function('Preview'),
        enable_devicons: enable_devicons,
        key_callbacks: extend(key_callbacks, selector.split_edit_callbacks),
    }))
    menu_wid = wids.menu
    popup_setoptions(menu_wid, {title: len(mru_list)})
enddef
