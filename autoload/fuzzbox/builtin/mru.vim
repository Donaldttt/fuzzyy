vim9script

import autoload '../utils/selector.vim'
import autoload '../utils/previewer.vim'
import autoload '../utils/devicons.vim'
import autoload '../utils/helpers.vim'

var mru_origin_list: list<string>
var cwd: string
var cwd_only: bool
var cwdlen: number
var fs = helpers.PathSep()
var menu_wid: number

# Options
var file_exclude = exists('g:fuzzbox_mru_exclude_file')
    && type(g:fuzzbox_mru_exclude_file) == v:t_list ?
    g:fuzzbox_mru_exclude_file : g:fuzzbox_exclude_file
var dir_exclude = exists('g:fuzzbox_mru_exclude_dir')
    && type(g:fuzzbox_mru_exclude_dir) == v:t_list ?
    g:fuzzbox_mru_exclude_dir : g:fuzzbox_exclude_dir

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if result == ''
        previewer.PreviewText(wid, '')
        return
    endif
    var path = cwd_only ? cwd .. '/' .. result : result
    path = path == '' ? path : fnamemodify(path, ':p')
    previewer.PreviewFile(wid, path)
    win_execute(wid, 'norm! gg')
enddef

def Select(wid: number, result: list<any>)
    var path = result[0]
    helpers.MoveToUsableWindow()
    if cwd_only
        exe 'edit ' cwd .. '/' .. fnameescape(path)
    else
        exe 'edit ' .. fnameescape(path)
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
    selector.UpdateMenu(mru_list, [])
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
            return stridx(fnamemodify(val, ':p'), cwd .. fs) >= 0
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
        async: true,
        devicons: true,
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        key_callbacks: extend(key_callbacks, selector.open_file_callbacks),
    }))
    menu_wid = wids.menu
enddef
