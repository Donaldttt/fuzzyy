vim9scrip

import autoload 'utils/selector.vim'

var max_count = 1000
var rg_cmd = 'rg --column -M200 --vimgrep --max-count=' .. max_count .. ' "%s" "%s"'
var ag_cmd = 'ag --column -W200 --vimgrep --max-count=' .. max_count .. ' "%s" "%s"'
var grep_cmd = 'grep -n -r --max-count=' .. max_count .. ' "%s" "%s"'
var sep_pattern = '\:\d\+:\d\+:'
var loading = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

var cmd: string 
if executable('ag')
    cmd = ag_cmd
elseif executable('grep')
    cmd = grep_cmd
    sep_pattern = '\:\d\+:'
elseif executable('rg')
    # not sure why rg has bad delay using job_start
    cmd = rg_cmd
endif

var cwd: string
var cwdlen = -1
var cur_pattern = ''
var cur_result = []
var menu_wid = -1
var cur_menu_item = ''
var job_running = 0
var ag_update_tid = 0
var last_pattern = ''
var last_result_len = -1
var last_result = []
var cur_dict = {}
var jid: job
var preview_wid = -1

# @return [path, linenr]
def ParseAgStr(str: string): list<any>
    var seq = matchstrpos(str, sep_pattern)
    if seq[1] == -1
        return [v:null, -1, -1]
    endif
    # var path = str[: seq[1] - 1]
    var path = strpart(str, 0, seq[1])
    var linecol = split(seq[0], ':')
    var line = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    else
        col = 0
    endif
    return [path, line, col]
enddef

def Reducer(pattern: string, acc: dict<any>, val: string): dict<any>
    var seq = matchstrpos(val, sep_pattern)
    if seq[1] == -1
        return acc
    endif

    var linecol = split(seq[0], ':')
    var line: number = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    endif
    #var path = val[: seq[1] - 1]
    #var str = val[seq[2] :]
    var path = strpart(val, 0, seq[1])
    var str = strpart(val, seq[2])
    var colstart = max([col - 40, 0])
    var centerd_str = strpart(str, colstart, colstart + 40)
    # var relative_path = path[len(cwd) + 1 :]
    var relative_path = strpart(path, len(cwd) + 1)

    var offset = len(relative_path) + len(seq[0]) + 1
    var match_cols: list<any>
    try
        match_cols = matchfuzzypos([str], pattern)[1]
    catch
        echoerr [val, centerd_str, pattern]
    endtry

    var final_str = relative_path .. seq[0] .. centerd_str
    var col_list = []
    if len(match_cols) > 0
        col_list = reduce(match_cols[0],  (a, v) => add(a, v + offset), [])
        acc.dict[final_str] = match_cols[0]
    endif
    var obj = {
        prefix: relative_path .. seq[0],
        centerd_str: centerd_str,
        col_list: col_list,
    }
    add(acc.objs, obj)
    add(acc.strs, final_str)
    add(acc.cols, col_list)
    return acc
enddef

def JobHandler(channel: channel, msg: string)
    var lists = selector.Split(msg)
    cur_result += lists 
enddef

def AgJobStart(pattern: string)
    if type(jid) == v:t_job
        try | job_stop(jid) | catch | endtry
    endif
    cur_result = []
    if pattern == ''
        return
    endif
    job_running = 1
    var cmd_str = printf(cmd, pattern, cwd)
    jid = job_start(cmd_str, {
        out_cb: function('JobHandler'),
        out_mode: 'raw',
        exit_cb: function('ExitCb'),
    })
enddef

def ExitCb(id: job, status: number)
    if id == jid
        job_running = 0
    endif
enddef

def ResultHandle(lists: list<any>): list<any>
    if cur_pattern == ''
        return [[], [], {}]
    endif
    var result = reduce(lists, function('Reducer', [cur_pattern]),
         { 'strs': [], 'cols': [], 'objs': [], 'dict': {} })
    var fuzzy_results = matchfuzzypos(result.objs, cur_pattern, {'key': 'centerd_str', 'limit': 10000})
    var strs = []
    var cols = []
    var idx = 0
    for r in fuzzy_results[0]
        var final_str = r.prefix .. r.centerd_str
        add(strs, final_str)
        add(cols, reduce(fuzzy_results[1][idx], (a, v) => add(a, v + len(r.prefix) + 1), []))
        idx += 1
    endfor
    return [strs, cols, result.dict]
enddef


# async version
def Input(wid: number, args: dict<any>, ...li: list<any>)
    var pattern = args.str
    cur_pattern = pattern
    AgJobStart(pattern)
enddef

def UpdatePreviewHl()
    if !has_key(cur_dict, cur_menu_item)
        return
    endif
    var [path, linenr, colnr] = ParseAgStr(cur_menu_item)
    clearmatches(preview_wid)
    var hl_list = []
    for col in cur_dict[cur_menu_item]
        add(hl_list, [linenr, col + 1])
    endfor
    matchaddpos('cursearch', hl_list, 9999, -1,  {'window': preview_wid})
enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    var last_item = opts.last_cursor_item
    var [path, linenr, colnr] = ParseAgStr(result)
    var last_path: string
    var last_linenr: number
    if type(last_item) == v:t_string && last_item != ''
        [last_path, last_linenr, _] = ParseAgStr(last_item)
    else
        [last_path, last_linenr] = ['', -1]
    endif
    cur_menu_item = result

    if !path || !filereadable(path)
        if path == v:null
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, path .. ' not found')
        endif
        return 
    endif

    if path != last_path
        var preview_bufnr = winbufnr(preview_wid)
        var fileraw = readfile(path)
        var ext = fnamemodify(path, ':e')
        var ft = selector.GetFt(ext)
        popup_settext(preview_wid, fileraw)
        # set syntax won't invoke some error cause by filetype autocmd
        try
            setbufvar(preview_bufnr, '&syntax', ft)
        catch
        endtry
    endif
    if path != last_path || linenr != last_linenr
        win_execute(preview_wid, 'norm ' .. linenr .. 'G')
        win_execute(preview_wid, 'norm! zz')
    endif
    UpdatePreviewHl()
enddef

def Select(wid: number, result: list<any>)
    var [path, linenr, _] = ParseAgStr(result[0])
    if path == v:null
        return
    endif
    execute('edit ' .. path)
    exe 'norm! ' .. linenr .. 'G'
    exe 'norm! zz'
enddef

def AgUpdateMenu(...li: list<any>)
    if job_running
        var time = float2nr(str2float(reltime()->reltimestr()[4 : ]) * 1000)
        var speed = 100
        var loadidx = (time % speed) / len(loading) 
        popup_setoptions(menu_wid, {'title': string(len(cur_result)) .. loading[loadidx]})
    else
        popup_setoptions(menu_wid, {'title': string(len(cur_result))})
    endif
    var cur_result_len = len(cur_result)

    if last_pattern == cur_pattern
        && cur_result_len == last_result_len
        return
    endif

    if cur_pattern == ''
        selector.UpdateMenu([], [])
        last_pattern = cur_pattern
        last_result_len = cur_result_len
        return
    endif

    var strs: list<string>
    var cols: list<list<number>>
    if cur_result_len == 0
        # we should use last result to do fuzzy search
        [strs, cols, cur_dict] = ResultHandle(last_result[: 2000])
    else
        last_result = cur_result
        [strs, cols, cur_dict] = ResultHandle(cur_result[: 2000])
    endif

    var idx = 1
    var hl_list = []
    for col in cols
        add(hl_list, [idx, col])
        idx += 1
    endfor
    selector.UpdateMenu(strs[: 100], hl_list[: 100])
    UpdatePreviewHl()
    last_pattern = cur_pattern
    last_result_len = cur_result_len
enddef

def CloseCb(...li: list<any>)
    timer_stop(ag_update_tid) 
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
enddef

def Profiling()
    profile start ~/.vim/vim.log
    profile func AgStart
    profile func AgUpdateMenu
    profile func Preview
    profile func UpdatePreviewHl
    profile func JobHandler
    profile func ResultHandle
    profile func Reducer
enddef

export def AgStart()
    cwd = getcwd()
    cwdlen = len(cwd)
    cur_pattern = ''
    cur_result = []
    cur_menu_item = ''
    job_running = 0

    ag_update_tid = 0
    last_pattern = ''
    last_result_len = -1
    last_result = []
    cur_dict = {}

    var ret = selector.Start([],
     {
         select_cb:  function('Select'),
         input_cb:  function('Input'),
         preview_cb:  function('Preview'),
         preview:  1,
         scrollbar:  0,
         close_cb:  function('CloseCb'),
     })
    menu_wid = ret[0]
    preview_wid = ret[2]
    setwinvar(menu_wid, '&wrap', 0)
    # setwinvar(preview_wid, '&cursorline', 1)
    # setwinvar(preview_wid, '&cursorlineopt', 'line')
    ag_update_tid = timer_start(100, function('AgUpdateMenu'), {'repeat': -1})
    # Profiling()
enddef
