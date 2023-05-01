vim9script

import autoload 'utils/selector.vim'

var last_result_len = -1
var cur_pattern = ''
var in_loading = 1
var cwd = getcwd()
var cwdlen = len(cwd)
var input_timer = -1
var cur_result = []
var jid: job
var menu_wid: number
var files_update_tid = -1

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

def InputUpdate(...li: list<any>)
    var [file_sorted_list, hl_list] = selector.FuzzySearch(cur_result, cur_pattern, 10000)
    g:MenuSetText(menu_wid, file_sorted_list[: 100])
    g:MenuSetHl('select', menu_wid, hl_list[: 100])
    popup_setoptions(menu_wid, {'title': len(cur_result)})
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
        if len(file_list) > 10000
            timer_stop(input_timer)
            input_timer = timer_start(100, function('InputUpdate'))
        else
            InputUpdate()
        endif
    else
        g:MenuSetText(menu_wid, cur_result[: 100])
        g:MenuSetHl('select', menu_wid, [])
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
    var fileraw = readfile(result)
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
    echom['err']
enddef

def ExitCb(j: job, status: number)
    in_loading = 0
	if last_result_len <= 0
		g:MenuSetText(menu_wid, cur_result[: 100])
	endif
    timer_stop(files_update_tid)
    popup_setoptions(menu_wid, {'title': len(cur_result)})
enddef

def JobHandler(channel: channel, msg: string)
    var lists = selector.Split(msg)
    cur_result += lists
enddef

def FilesUpdateMenu(...li: list<any>)
    var cur_result_len = len(cur_result)
    popup_setoptions(menu_wid, {'title': string(len(cur_result))})
    if cur_result_len == last_result_len
        return
    endif
    last_result_len = cur_result_len

    try
        var [file_sorted_list, hl_list] = selector.FuzzySearch(cur_result, cur_pattern, 10000)
        g:MenuSetText(menu_wid, file_sorted_list[: 100])
        g:MenuSetHl('select', menu_wid, hl_list[: 100])
    catch
        # echom ['error in files_update_menu']
    endtry
enddef

export def FilesStart()
	last_result_len = -1
	cur_pattern = ''
	in_loading = 1
    cwd = getcwd()
    cwdlen = len(cwd)
    FilesJobStart(cwd)
    var winds = selector.Start([], {
	 select_cb:  function('Select'),
     preview_cb:  function('Preview'),
     input_cb:  function('Input'),
     preview:  1,
     infowin:  0,
     prompt: pathshorten(fnamemodify(cwd, ':~' )) .. (has('win32') ? '\ ' : '/ '),
     })
    menu_wid = winds[0]
    timer_start(50, function('FilesUpdateMenu'))
    files_update_tid = timer_start(400, function('FilesUpdateMenu'), {'repeat': -1})
    autocmd User PopupClosed ++once try | job_stop(jid) | timer_stop(files_update_tid) | catch | endtry
enddef
