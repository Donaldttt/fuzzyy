vim9script

import autoload './utils/selector.vim'
import autoload './utils/devicons.vim'
import autoload './utils/cmdbuilder.vim'

var last_result_len: number
var cur_pattern: string
var last_pattern: string
var in_loading: number
var cwd: string
var cur_result: list<string>
var jid: job
var menu_wid: number
var update_tid: number
var cache: dict<any>
var enable_devicons = devicons.Enabled()

def ProcessResult(list_raw: list<string>, ...args: list<any>): list<string>
    var limit = -1
    var li: list<string>
    if len(args) > 0
        li = list_raw[: args[0]]
    else
        li = list_raw
    endif
    if enable_devicons
        devicons.AddDevicons(li)
    endif
    # Hack for Git-Bash / Mingw-w64, Cygwin, and possibly other friends
    # External commands like rg may return paths with Windows file separator,
    # but Vim thinks it has a UNIX environment, so needs UNIX file separator
    map(li, (_, val) => fnamemodify(val, ':.'))
    return li
enddef

def Select(wid: number, result: list<any>)
    var relative_path = result[0]
    if enable_devicons
        relative_path = devicons.RemoveDevicon(relative_path)
    endif
    var path = cwd .. '/' .. relative_path
    selector.MoveToUsableWindow()
    exe 'edit ' .. fnameescape(path)
enddef

def AsyncCb(result: list<any>)
    var strs = []
    var hl_list = []
    var hl_offset = enable_devicons ? devicons.GetDeviconOffset() : 0
    var idx = 1
    for item in result
        add(strs, item[0])
        hl_list += reduce(item[1], (acc, val) => {
            var pos = copy(val)
            pos[0] += hl_offset
            add(acc, [idx] + pos)
            return acc
        }, [])
        idx += 1
    endfor
    selector.UpdateMenu(ProcessResult(strs), hl_list)
    popup_setoptions(menu_wid, {title: selector.total_results})
enddef

def Input(wid: number, val: dict<any>, ...li: list<any>)
    var pattern = val.str
    cur_pattern = pattern

    # when in loading state, files_update_menu will handle the input
    if in_loading
        return
    endif

    var file_list = cur_result

    if pattern != ''
        selector.FuzzySearchAsync(cur_result, cur_pattern, 200, function('AsyncCb'))
    else
        selector.UpdateMenu(ProcessResult(cur_result, 100), [])
        popup_setoptions(menu_wid, {title: len(cur_result)})
    endif
enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if enable_devicons
        result = devicons.RemoveDevicon(result)
    endif
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    win_execute(preview_wid, 'syntax clear')
    var path = cwd .. '/' .. result
    if !filereadable(path)
        if result == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, result .. ' not found')
        endif
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    if selector.IsBinary(path)
        popup_settext(preview_wid, 'Cannot preview binary file')
    else
        var content = readfile(path, '', 1000)
        popup_settext(preview_wid, content)
        setwinvar(preview_wid, '&filetype', '')
        win_execute(preview_wid, 'silent! doautocmd filetypedetect BufNewFile ' .. path)
        win_execute(preview_wid, 'silent! setlocal nospell nolist')
        if empty(getwinvar(preview_wid, '&filetype')) || getwinvar(preview_wid, '&filetype') == 'conf'
            var modelineft = selector.FTDetectModelines(content)
            if !empty(modelineft)
                win_execute(preview_wid, 'set filetype=' .. modelineft)
            endif
        endif
    endif
    win_execute(preview_wid, 'norm! gg')
enddef

def JobStart(path: string, cmd: string)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    cur_result = []
    if path == ''
        return
    endif
    jid = job_start(cmd, {
        out_cb: function('JobOutCb'),
        out_mode: 'raw',
        exit_cb: function('JobExitCb'),
        err_cb: function('JobErrCb'),
        cwd: path
    })
enddef

def JobOutCb(channel: channel, msg: string)
    var lists = selector.Split(msg)
    cur_result += lists
enddef

def JobErrCb(channel: channel, msg: string)
    echoerr msg
enddef

def JobExitCb(id: job, status: number)
    in_loading = 0
    timer_stop(update_tid)
    if last_result_len <= 0
        selector.UpdateMenu(ProcessResult(cur_result, 100), [])
    endif
    popup_setoptions(menu_wid, {title: len(cur_result)})
enddef

def Profiling()
    profile start ~/.vim/vim.log
    profile func Input
    profile func Reducer
    profile func Preview
    profile func JobHandler
    profile func UpdateMenu
enddef

def UpdateMenu(...li: list<any>)
    var cur_result_len = len(cur_result)
    popup_setoptions(menu_wid, {title: string(len(cur_result))})
    if cur_result_len == last_result_len
        return
    endif
    last_result_len = cur_result_len

    if cur_pattern != last_pattern
        selector.FuzzySearchAsync(cur_result, cur_pattern, 200, function('AsyncCb'))
        if cur_pattern == ''
            selector.UpdateMenu(ProcessResult(cur_result, 100), [])
        endif
        last_pattern = cur_pattern
    endif
enddef

def Close(wid: number, opts: dict<any>)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    timer_stop(update_tid)
enddef

export def Start(opts: dict<any> = {})
    last_result_len = -1
    cur_result = []
    cur_pattern = ''
    last_pattern = '@!#-='
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    in_loading = 1
    var wids = selector.Start([], extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        input_cb: function('Input'),
        close_cb: function('Close'),
        enable_devicons: enable_devicons,
        key_callbacks: selector.split_edit_callbacks,
    }))
    menu_wid = wids.menu
    if menu_wid == -1
        return
    endif
    var cmd: string
    if len(get(opts, 'command', '')) > 0
        cmd = opts.command
    else
        cmd = cmdbuilder.Build()
    endif
    JobStart(cwd, cmd)
    timer_start(50, function('UpdateMenu'))
    update_tid = timer_start(400, function('UpdateMenu'), {repeat: -1})
    # Profiling()
enddef
