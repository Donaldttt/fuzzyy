vim9script

import autoload 'utils/selector.vim'

var last_result_len = -1
var cur_pattern = ''
var last_pattern = ''
var in_loading = 1
var cwd: string
var cwdlen: number
var input_timer = -1
var cur_result = []
var jid: job
var menu_wid: number
var files_update_tid = -1
var cache: dict<any>

def Reducer(acc: list<string>, val: string): list<string>
    if isdirectory(val)
        return acc
    endif
    add(acc, val[cwdlen + 1 :])
    return acc
enddef

def Files(...li: list<any>): list<string>
    var path = cwd
    if len(li) > 0
        path = li[0]
    endif
    var files: list<string>
    if has('win32')
        files = glob(path . '/**', 1, 1, 1)
    else
        files = systemlist('find ' .. path .. ' -type f -not -path "*/.git/*"')
    endif
    files = reduce(files, function('Reducer'), [])
    return files
enddef

def Select(wid: number, result: list<any>)
    var path = result[0]
    execute('edit ' .. path)
enddef

#def InputUpdate(...li: list<any>)
#    var [file_sorted_list, hl_list] = selector.FuzzySearch(cur_result, cur_pattern, 1000)
#    selector.UpdateMenu(file_sorted_list[: 100], hl_list[: 100])
#    popup_setoptions(menu_wid, {'title': len(cur_result)})
#enddef
def AsyncCb(result: list<any>)
    var strs = []
    var hl_list = []
    var idx = 1
    for item in result
        add(strs, item[0])
        hl_list += reduce(item[1], (acc, val) => add(acc, [idx, val + 1]), [])
        idx += 1
    endfor
    selector.UpdateMenu(strs, hl_list)
enddef

def InputUpdate(...li: list<any>)
    selector.FuzzySearchAsync(cur_result, cur_pattern, 200, function('AsyncCb'))
enddef

def Input(wid: number, val: dict<any>, ...li: list<any>)
    var pattern = val.str
    cur_pattern = pattern

    # when in loading state, files_update_menu will handle the input
    if in_loading
        return
    endif

    var file_list = cur_result
    var hl_list = []

    if pattern != ''
       #if len(file_list) > 10000
       #    timer_stop(input_timer)
       #    input_timer = timer_start(100, function('InputUpdate'))
       #else
            InputUpdate()
       #endif
    else
        selector.UpdateMenu(cur_result[: 100], [])
        popup_setoptions(menu_wid, {'title': len(cur_result)})
    endif

enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    var preview_wid = opts.win_opts.partids['preview']
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
    # set syntax won't invoke some error cause by filetype autocmd
    try
        setbufvar(preview_bufnr, '&syntax', ft)
    catch
    endtry
enddef

def FilesJobStart(path: string)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    cur_result = []
    if path == ''
        return
    endif
    var cmdstr: string
    if has('win32')
        cmdstr = 'powershell -command "gci . -r -n -File"'
    else
        cmdstr = 'find . -type f -not -path "*/.git/*"'
    endif
    jid = job_start(cmdstr, {
     out_cb: function('JobHandler'),
     out_mode: 'raw',
     exit_cb: function('ExitCb'),
     err_cb: function('ErrCb'),
     cwd: path
     })
enddef

def ErrCb(channel: channel, msg: string)
    # echom ['err']
enddef

def ExitCb(j: job, status: number)
    in_loading = 0
    timer_stop(files_update_tid)
	if last_result_len <= 0
        selector.UpdateMenu(cur_result[: 100], [])
	endif
    popup_setoptions(menu_wid, {'title': len(cur_result)})
enddef

def JobHandler(channel: channel, msg: string)
    var lists = selector.Split(msg)
    cur_result += lists
enddef

def Profiling()
    profile start ~/.vim/vim.log
    profile func Input
    profile func Reducer
    profile func Preview
    profile func JobHandler
    profile func FilesUpdateMenu
enddef

def FilesUpdateMenu(...li: list<any>)
    var cur_result_len = len(cur_result)
    popup_setoptions(menu_wid, {'title': string(len(cur_result))})
    if cur_result_len == last_result_len
        return
    endif
    last_result_len = cur_result_len

        #var [file_sorted_list, hl_list] = selector.FuzzySearch(cur_result, cur_pattern, 1000)
        #selector.UpdateMenu(file_sorted_list[: 100], hl_list[: 100])
        if cur_pattern != last_pattern
            selector.FuzzySearchAsync(cur_result, cur_pattern, 200, function('AsyncCb'))
            if cur_pattern == ''
                selector.UpdateMenu(cur_result[: 100], [])
            endif
            last_pattern = cur_pattern
        endif
enddef

def Close(wid: number, opts: dict<any>)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    timer_stop(files_update_tid)
enddef

export def FilesStart()
    last_result_len = -1
    cur_result = []
    cur_pattern = ''
    last_pattern = ''
    cwd = getcwd()
    cwdlen = len(cwd)
    FilesJobStart(cwd)
    in_loading = 1
    var winds = selector.Start([], {
        select_cb:  function('Select'),
        preview_cb:  function('Preview'),
        input_cb:  function('Input'),
        close_cb:  function('Close'),
        reverse_menu: 1,
        preview:  1,
        infowin: 1,
        scrollbar: 0,
        # prompt: pathshorten(fnamemodify(cwd, ':~' )) .. (has('win32') ? '\ ' : '/ '),
     })
    var info_wid = winds[3]
    popup_settext(info_wid, 'cwd: ' .. fnamemodify(cwd, ':~' ) .. (has('win32') ? '\ ' : '/ '))
    menu_wid = winds[0]
    timer_start(50, function('FilesUpdateMenu'))
    files_update_tid = timer_start(400, function('FilesUpdateMenu'), {'repeat': -1})
    # Profiling()
enddef
